//
// Copyright (c) 2026 Enjel Hutasoit
//

import UIKit
import WebKit

public enum ContainerError: Error, Equatable {
    case loadFailed(String)
    case timeout
    case offline
    case contentProcessTerminated
}

public protocol BridgeContainerDelegate: AnyObject {
    func containerDidEncounter(_ error: ContainerError)
    func containerDidFinishLoad()
}

/// Pure allowlist logic — deliberately holds no WKWebView reference so it is
/// unit-testable without instantiating WebKit.
public struct NavigationAllowlist {
    public let allowedHosts: Set<String>
    
    public init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
    }
    
    public func isAllowed(url: URL?) -> Bool {
        guard let host = url?.host else { return false }
        return allowedHosts.contains(host)
    }
}

public final class BridgeContainerViewController: UIViewController {
    public weak var delegate: BridgeContainerDelegate?
    public let allowlist: NavigationAllowlist
    public let webView: WKWebView
    private var loadTimeoutWorkItem: DispatchWorkItem?
    private let loadTimeoutSeconds: TimeInterval
    
    public init(allowlist: NavigationAllowlist, loadTimeoutSeconds: TimeInterval = 15) {
        self.allowlist = allowlist
        self.loadTimeoutSeconds = loadTimeoutSeconds
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(nibName: nil, bundle: nil)
        self.webView.navigationDelegate = self
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
    }
    
    public func load(url: URL) {
        guard allowlist.isAllowed(url: url) else {
            delegate?.containerDidEncounter(.loadFailed("origin not allowlisted: \(url.host ?? "nil")"))
            return
        }
        startTimeoutWatch()
        webView.load(URLRequest(url: url))
    }
    
    /// Recovery path for a killed WebContent process: reload the last good URL.
    public func recoverFromContentProcessTermination() {
        if let url = webView.url {
            load(url: url)
        }
    }
    
    private func startTimeoutWatch() {
        loadTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.delegate?.containerDidEncounter(.timeout)
        }
        loadTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + loadTimeoutSeconds, execute: workItem)
    }
    
    /// Layered on top by WBKBridge's bridge-transport code (Day 2). This class
    /// knows nothing about message schemas or callbacks — single responsibility.
    public func installUserScript(_ script: WKUserScript) {
        webView.configuration.userContentController.addUserScript(script)
    }
    
    /// Wraps `handler` in ScriptMessageHandlerProxy before registering it.
    /// WITHOUT this, WKUserContentController retains `handler` strongly, and
    /// if `handler` (directly or transitively) retains this container, you
    /// get container -> webView -> userContentController -> handler ->
    /// container. This wrap is the fix, not optional — see
    /// ScriptMessageHandlerProxy's own doc comment.
    ///
    /// The caller must keep its own strong reference to `handler` — this
    /// container intentionally does not, so the container never becomes the
    /// thing keeping a possibly-container-owning object alive.
    public func addScriptMessageHandler(_ handler: WKScriptMessageHandler, name: String) {
        let proxy = ScriptMessageHandlerProxy(target: handler)
        webView.configuration.userContentController.add(proxy, name: name)
    }
    
    public func evaluateJavaScript(_ js: String, completion: ((Result<Any?, Error>) -> Void)? = nil) {
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(result))
            }
        }
    }
}

/// Seam for testability: BridgeCore (Day 2) originally held a concrete
/// BridgeContainerViewController — a UIViewController, which cannot be
/// constructed headlessly for a pure-logic unit test. This protocol lets
/// tests substitute a plain fake instead. Added Day 9 while building out
/// the test suite; the gap only became visible once we tried to test
/// BridgeCore in isolation.
@MainActor
public protocol JavaScriptEvaluating: AnyObject {
    func evaluateJavaScript(
        _ js: String,
        completion: ((Result<Any?, Error>) -> Void)?
    )
}

extension BridgeContainerViewController: JavaScriptEvaluating {}

extension BridgeContainerViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadTimeoutWorkItem?.cancel()
        delegate?.containerDidFinishLoad()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadTimeoutWorkItem?.cancel()
        delegate?.containerDidEncounter(.loadFailed(error.localizedDescription))
    }
    
    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        loadTimeoutWorkItem?.cancel()
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
            delegate?.containerDidEncounter(.offline)
        } else {
            delegate?.containerDidEncounter(.loadFailed(error.localizedDescription))
        }
    }
    
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        delegate?.containerDidEncounter(.contentProcessTerminated)
    }
}

extension BridgeContainerViewController {
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if allowlist.isAllowed(url: navigationAction.request.url) {
            decisionHandler(.allow)
        } else {
            let url = navigationAction.request.url?.absoluteString ?? "nil"
            delegate?.containerDidEncounter(.loadFailed("blocked navigation: \(url)"))
            decisionHandler(.cancel)
        }
    }
}
