import XCTest
@testable import UnlockBriefingCore

final class ResidencyPolicyTests: XCTestCase {
    func testApplyDisablesAutomaticTerminationOnThisProcess() {
        XCTAssertFalse(
            ResidencyPolicy.terminateAfterLastWindowClosed,
            "closing the last window must not quit the accessory process"
        )

        ResidencyPolicy.apply()

        XCTAssertFalse(
            ProcessInfo.processInfo.automaticTerminationSupportEnabled,
            "shipped apply() must turn off AppKit automatic termination"
        )
    }
}
