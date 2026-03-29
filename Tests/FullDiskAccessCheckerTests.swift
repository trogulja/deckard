import XCTest
@testable import Deckard

final class FullDiskAccessCheckerTests: XCTestCase {
    func testHasFullDiskAccessReturnsBool() {
        // Smoke test — the function runs without crashing and returns a Bool.
        // The actual result depends on the test host's FDA status.
        let result = FullDiskAccessChecker.hasFullDiskAccess()
        XCTAssertNotNil(result as Bool)
    }

    func testOpenSettingsURLIsValid() {
        // Verify the URL string parses correctly.
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        XCTAssertNotNil(url)
    }
}
