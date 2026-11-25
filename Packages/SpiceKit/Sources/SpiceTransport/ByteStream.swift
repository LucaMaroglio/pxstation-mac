import Foundation
import SpiceWire

/// A reliable, ordered byte stream (TCP, optionally TLS and/or through a proxy).
///
/// The channel layer only depends on this protocol, which keeps protocol logic testable
/// with in-memory streams. Exactly one task reads from a stream at a time.
public protocol SpiceByteStream: Sendable {
    func send(_ bytes: [UInt8]) async throws
    /// Returns exactly `count` bytes or throws (`TransportError.closed` on EOF).
    func receive(exactly count: Int) async throws -> [UInt8]
    func close() async
}

/// Errors from connecting, linking and authenticating a channel.
public enum TransportError: Error, Equatable, Sendable, LocalizedError {
    case connectionFailed(String)
    case closed
    case timedOut
    case tlsVerificationFailed(String)
    case proxyRefused(status: Int)
    case proxyProtocolError
    /// Server rejected the link (`SpiceLinkErr`).
    case linkRejected(LinkError)
    /// Server rejected the ticket.
    case authenticationFailed(LinkError)
    case unsupportedServer(String)
    case protocolViolation(String)
    case ticketTooLong
    case encryptionFailed
    /// The connection file asks for security the connection can't provide
    /// (TLS required without a TLS port, unusable CA or host subject).
    case insecureConfiguration(String)
    /// No port configured for this channel.
    case noRoute

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            String(localized: "Could not connect to the server (\(reason)).", bundle: .main)
        case .closed:
            String(localized: "The server closed the connection.", bundle: .main)
        case .timedOut:
            String(localized: "The connection timed out.", bundle: .main)
        case .tlsVerificationFailed(let reason):
            String(localized: "The server’s certificate could not be verified (\(reason)).", bundle: .main)
        case .proxyRefused(let status) where status == 401 || status == 403:
            String(localized: "The proxy rejected the connection (HTTP \(status)). With Proxmox this usually means the connection file has expired: click SPICE again and open the new file right away.", bundle: .main)
        case .proxyRefused(let status):
            String(localized: "The proxy refused the connection (HTTP \(status)).", bundle: .main)
        case .proxyProtocolError:
            String(localized: "The proxy sent an invalid response.", bundle: .main)
        case .linkRejected(let error):
            String(localized: "The server rejected the connection (\(String(describing: error))).", bundle: .main)
        case .authenticationFailed(.permissionDenied):
            String(localized: "The ticket has expired or is invalid. Download a fresh connection file and try again.", bundle: .main)
        case .authenticationFailed(let error):
            String(localized: "Authentication failed (\(String(describing: error))).", bundle: .main)
        case .unsupportedServer(let reason):
            String(localized: "The server is not supported: \(reason).", bundle: .main)
        case .protocolViolation(let reason):
            String(localized: "The server sent unexpected data (\(reason)).", bundle: .main)
        case .ticketTooLong:
            String(localized: "The ticket in the connection file is too long.", bundle: .main)
        case .encryptionFailed:
            String(localized: "Could not encrypt the ticket for the server.", bundle: .main)
        case .insecureConfiguration(let reason):
            String(localized: "The connection file’s security settings can’t be met (\(reason)). Not connecting.", bundle: .main)
        case .noRoute:
            String(localized: "The connection file doesn’t specify a port for this connection.", bundle: .main)
        }
    }
}

/// In-memory pair of streams for tests and loopback use.
public actor MemoryByteStream: SpiceByteStream {
    private var inbound: [UInt8] = []
    private var waiters: [(count: Int, continuation: CheckedContinuation<[UInt8], any Error>)] = []
    private var closed = false
    private weak var peer: MemoryByteStream?

    public init() {}

    /// Creates two connected endpoints.
    public static func pair() async -> (MemoryByteStream, MemoryByteStream) {
        let a = MemoryByteStream(), b = MemoryByteStream()
        await a.connect(to: b)
        await b.connect(to: a)
        return (a, b)
    }

    private func connect(to other: MemoryByteStream) { peer = other }

    public func send(_ bytes: [UInt8]) async throws {
        guard !closed, let peer else { throw TransportError.closed }
        await peer.deliver(bytes)
    }

    fileprivate func deliver(_ bytes: [UInt8]) {
        inbound.append(contentsOf: bytes)
        satisfyWaiters()
    }

    public func receive(exactly count: Int) async throws -> [UInt8] {
        if inbound.count >= count {
            defer { inbound.removeFirst(count) }
            return Array(inbound.prefix(count))
        }
        if closed { throw TransportError.closed }
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    private func satisfyWaiters() {
        while let first = waiters.first, inbound.count >= first.count {
            waiters.removeFirst()
            let chunk = Array(inbound.prefix(first.count))
            inbound.removeFirst(first.count)
            first.continuation.resume(returning: chunk)
        }
    }

    public func close() async {
        guard !closed else { return }
        closed = true
        for waiter in waiters { waiter.continuation.resume(throwing: TransportError.closed) }
        waiters.removeAll()
        if let peer { await peer.peerClosed() }
    }

    fileprivate func peerClosed() {
        closed = true
        for waiter in waiters { waiter.continuation.resume(throwing: TransportError.closed) }
        waiters.removeAll()
    }
}
