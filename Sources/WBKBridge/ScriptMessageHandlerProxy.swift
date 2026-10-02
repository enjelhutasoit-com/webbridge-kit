//
// Copyright (c) 2026 Enjel Hutasoit
//

import WebKit

/// WKUserContentController holds a STRONG reference to whatever you `add()` as
/// a message handler. If that object is your view controller, you get a retain
/// cycle: controller -> webView -> userContentController -> handler -> controller.
/// This weak proxy breaks the cycle. Confirmed necessary pattern for any
/// WKScriptMessageHandler-based bridge.
final class ScriptMessageHandlerProxy: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    
    init(target: WKScriptMessageHandler) {
        self.target = target
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
