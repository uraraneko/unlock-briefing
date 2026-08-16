import Foundation

/// Keep an accessory UnlockBriefing process alive with no windows so the
/// global hotkey and unlock listeners stay registered.
public enum ResidencyPolicy {
    public static let automaticTerminationReason = "stay resident for hotkey and unlock briefing"
    public static let terminateAfterLastWindowClosed = false

    public static func apply() {
        let process = ProcessInfo.processInfo
        process.automaticTerminationSupportEnabled = false
        process.disableAutomaticTermination(automaticTerminationReason)
        process.disableSuddenTermination()
    }
}
