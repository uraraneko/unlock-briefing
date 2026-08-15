import Foundation

public struct ProcessResult: Equatable, Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var succeeded: Bool { exitCode == 0 }

    public var combinedOutput: String {
        let parts = [stdout, stderr].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.joined(separator: "\n")
    }
}

public protocol ProcessRunning: AnyObject {
    @discardableResult
    func run(executable: String, arguments: [String], currentDirectory: URL?) throws -> ProcessResult
}

public enum GitExecutable {
    public static func resolve(fileManager: FileManager = .default) -> String {
        let candidates = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
        return candidates.first { fileManager.isExecutableFile(atPath: $0) } ?? "/usr/bin/git"
    }
}

public final class SystemProcessRunner: ProcessRunning, @unchecked Sendable {
    public init() {}

    public func run(executable: String, arguments: [String], currentDirectory: URL?) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.environment = ProcessInfo.processInfo.environment
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}

public final class RecordingProcessRunner: ProcessRunning, @unchecked Sendable {
    public struct Call: Equatable, Sendable {
        public var executable: String
        public var arguments: [String]
        public var directory: String?

        public init(executable: String, arguments: [String], directory: String?) {
            self.executable = executable
            self.arguments = arguments
            self.directory = directory
        }

        public var looksLikeGit: Bool {
            executable.contains("git") || arguments.contains(where: { $0.contains("git") })
        }
    }

    public private(set) var calls: [Call] = []
    public var inner: ProcessRunning?

    public init(inner: ProcessRunning? = nil) {
        self.inner = inner
    }

    public var invokedGit: Bool {
        calls.contains { $0.looksLikeGit }
    }

    public func run(executable: String, arguments: [String], currentDirectory: URL?) throws -> ProcessResult {
        calls.append(Call(executable: executable, arguments: arguments, directory: currentDirectory?.path))
        if let inner {
            return try inner.run(executable: executable, arguments: arguments, currentDirectory: currentDirectory)
        }
        return ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}
