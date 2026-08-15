import XCTest
@testable import UnlockBriefingCore

final class RepoURLPasteTests: XCTestCase {
    func testPasteReplacesCurrentURL() {
        let next = RepoURLPaste.apply(
            "  git@github.com:you/private-data.git \n",
            onto: "old"
        )
        XCTAssertEqual(next, "git@github.com:you/private-data.git")
    }

    func testEmptyClipboardKeepsCurrent() {
        XCTAssertEqual(RepoURLPaste.apply(nil, onto: "keep"), "keep")
        XCTAssertEqual(RepoURLPaste.apply("   \n", onto: "keep"), "keep")
    }
}
