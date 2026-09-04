import Foundation
import AIPowerCore

enum AppServerClientError: LocalizedError {
    case executableNotFound
    case launchFailed(String)
    case connectionClosed(String?)
    case invalidResponse
    case serverError(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Codex executable was not found."
        case .launchFailed(let reason):
            return "Codex app-server could not start: \(reason)"
        case .connectionClosed(let reason):
            return reason.map { "Codex app-server stopped: \($0)" } ?? "Codex app-server stopped."
        case .invalidResponse:
            return "Codex app-server returned an invalid response."
        case .serverError(let message):
            return message
        case .cancelled:
            return "The request was cancelled."
        }
    }
}

final class CodexAppServerClient {
    typealias Completion = (Result<RateLimitSnapshot, Error>) -> Void

    private let queue = DispatchQueue(label: "com.aipower.app-server")
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputBuffer = Data()
    private var errorBuffer = Data()
    private var initialized = false
    private var requestInFlight = false
    private var nextRequestID = 10
    private var activeRequestID: Int?
    private var completions: [Completion] = []
    private var stopping = false

    func fetchRateLimits(completion: @escaping Completion) {
        queue.async {
            self.completions.append(completion)
            self.startIfNeeded()
            self.issueRequestIfPossible()
        }
    }

    func stop() {
        queue.async {
            self.stopping = true
            let callbacks = self.completions
            self.completions.removeAll()
            callbacks.forEach { $0(.failure(AppServerClientError.cancelled)) }
            self.process?.terminationHandler = nil
            if self.process?.isRunning == true {
                self.process?.terminate()
            }
            self.cleanup()
            self.stopping = false
        }
    }

    private func startIfNeeded() {
        guard process == nil else { return }
        guard let executableURL = Self.resolveExecutable() else {
            failAll(AppServerClientError.executableNotFound)
            return
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.consumeOutput(data) }
        }
        errors.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async {
                self?.errorBuffer.append(data)
                if let count = self?.errorBuffer.count, count > 8_192 {
                    self?.errorBuffer.removeFirst(count - 8_192)
                }
            }
        }
        process.terminationHandler = { [weak self] terminatedProcess in
            self?.queue.async {
                guard let self, !self.stopping else { return }
                let message = String(data: self.errorBuffer, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.failAll(AppServerClientError.connectionClosed(message?.isEmpty == false ? message : nil))
                self.cleanup()
            }
        }

        do {
            try process.run()
            self.process = process
            inputPipe = input
            outputPipe = output
            errorPipe = errors
            send([
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "ai_power",
                        "title": "AI Power",
                        "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
                    ]
                ]
            ])
        } catch {
            cleanup()
            failAll(AppServerClientError.launchFailed(error.localizedDescription))
        }
    }

    private func issueRequestIfPossible() {
        guard initialized, !requestInFlight, !completions.isEmpty else { return }
        requestInFlight = true
        let id = nextRequestID
        nextRequestID += 1
        activeRequestID = id
        send(["method": "account/rateLimits/read", "id": id])
    }

    private func send(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object) else {
            failAll(AppServerClientError.invalidResponse)
            return
        }
        do {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(0x0A)
            try inputPipe?.fileHandleForWriting.write(contentsOf: data)
        } catch {
            failAll(AppServerClientError.connectionClosed(error.localizedDescription))
            cleanup()
        }
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            handleLine(Data(line))
        }
    }

    private func handleLine(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        guard let id = (object["id"] as? NSNumber)?.intValue else { return }

        if id == 0 {
            if let error = Self.errorMessage(in: object) {
                failAll(AppServerClientError.serverError(error))
                cleanup()
                return
            }
            initialized = true
            send(["method": "initialized", "params": [:]])
            issueRequestIfPossible()
            return
        }

        guard id == activeRequestID else { return }
        requestInFlight = false
        activeRequestID = nil
        let callbacks = completions
        completions.removeAll()

        if let error = Self.errorMessage(in: object) {
            callbacks.forEach { $0(.failure(AppServerClientError.serverError(error))) }
        } else {
            do {
                let snapshot = try RateLimitParser.parseResponse(object)
                callbacks.forEach { $0(.success(snapshot)) }
            } catch {
                callbacks.forEach { $0(.failure(error)) }
            }
        }
        issueRequestIfPossible()
    }

    private func failAll(_ error: Error) {
        let callbacks = completions
        completions.removeAll()
        requestInFlight = false
        activeRequestID = nil
        callbacks.forEach { $0(.failure(error)) }
    }

    private func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        try? inputPipe?.fileHandleForWriting.close()
        try? outputPipe?.fileHandleForReading.close()
        try? errorPipe?.fileHandleForReading.close()
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        outputBuffer.removeAll(keepingCapacity: true)
        errorBuffer.removeAll(keepingCapacity: true)
        initialized = false
        requestInFlight = false
        activeRequestID = nil
    }

    private static func errorMessage(in object: [String: Any]) -> String? {
        guard let error = object["error"] as? [String: Any] else { return nil }
        if let message = error["message"] as? String { return message }
        return String(describing: error)
    }

    private static func resolveExecutable() -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        if let path = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":")
            .map(String.init)
            .map({ URL(fileURLWithPath: $0).appendingPathComponent("codex").path })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
