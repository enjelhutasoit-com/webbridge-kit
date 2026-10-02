//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import Foundation
@testable import WBKBridge

final class NavigationAllowlistTests: XCTestCase {
    func test_givenListedHost_whenChecked_thenAllowed() {
        let allowlist = NavigationAllowlist(allowedHosts: ["partner.example.com"])
        XCTAssertTrue(allowlist.isAllowed(url: URL(string: "https://partner.example.com/app")))
    }
    
    func test_givenUnlistedHost_whenChecked_thenRejected() {
        let allowlist = NavigationAllowlist(allowedHosts: ["partner.example.com"])
        XCTAssertFalse(allowlist.isAllowed(url: URL(string: "https://evil.example.com/app")))
    }
    
    func test_givenNilURL_whenChecked_thenRejected() {
        let allowlist = NavigationAllowlist(allowedHosts: ["partner.example.com"])
        XCTAssertFalse(allowlist.isAllowed(url: nil))
    }
    
    func test_givenMultipleAllowedHosts_whenSecondHostChecked_thenAllowed() {
        let allowlist = NavigationAllowlist(allowedHosts: ["a.example.com", "b.example.com"])
        XCTAssertTrue(allowlist.isAllowed(url: URL(string: "https://b.example.com/x")))
    }
    
    func test_givenSubdomainNotInList_whenChecked_thenRejected() {
        // exact-host match only — no implicit subdomain trust
        let allowlist = NavigationAllowlist(allowedHosts: ["example.com"])
        XCTAssertFalse(allowlist.isAllowed(url: URL(string: "https://evil.example.com")))
    }
}
