import Foundation

enum ProviderDeadlineError: Error, Equatable {
    case timedOut
}

private final class ProviderDeadlineGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var progress: Progress?
    private var pendingResult: Result<Value, Error>?
    private var finished = false

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let pendingResult {
            finished = true
            self.pendingResult = nil
            lock.unlock()
            continuation.resume(with: pendingResult)
            return
        }
        guard !finished else { lock.unlock(); return }
        self.continuation = continuation
        lock.unlock()
    }

    func setProgress(_ progress: Progress) {
        lock.lock()
        self.progress = progress
        let shouldCancel = finished
        lock.unlock()
        if shouldCancel { progress.cancel() }
    }

    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard !finished, pendingResult == nil else { lock.unlock(); return }
        guard let continuation else {
            pendingResult = result
            lock.unlock()
            return
        }
        finished = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }

    func cancel(with error: Error) {
        lock.lock()
        let progress = progress
        lock.unlock()
        progress?.cancel()
        finish(.failure(error))
    }
}

enum ProviderDeadline {
    static func load<Value>(
        timeout: TimeInterval = 10,
        _ start: (@escaping (Result<Value, Error>) -> Void) -> Progress?
    ) async throws -> Value {
        let gate = ProviderDeadlineGate<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                if let progress = start({ gate.finish($0) }) {
                    gate.setProgress(progress)
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) {
                    gate.cancel(with: ProviderDeadlineError.timedOut)
                }
            }
        } onCancel: {
            gate.cancel(with: CancellationError())
        }
    }
}
