import AuvelProtocol
import AuvelSession
import AuvelTransport
import Foundation
import Network

/// The control connection to one paired Mac (protocol §5, §7): hello, state, commands, keep-alive and reconnect.
@MainActor
@Observable
final class RemoteSession {
    enum Status: Equatable {
        case connecting
        case connected
        /// Not found on this network or the connection dropped. Retrying.
        case unreachable
        /// The Mac's Auvel is too old or too new for this app (I13).
        case updateRequired(macIsOlder: Bool)
        /// The Mac removed this iPhone (protocol §7.4).
        case unpaired
    }

    let mac: StoredPairing
    private(set) var status: Status = .connecting
    /// Protocol state for the current connection. Shared and contract-tested (T2).
    private var logic = ClientSessionLogic()

    var state: MacState? { logic.state }
    var macModel: String { logic.macModel }
    /// Last error from a command, cleared on the next success.
    var lastFailure: ErrorCode? { logic.lastFailure }

    @ObservationIgnored private let deviceID: UUID
    @ObservationIgnored private let deviceName: String
    @ObservationIgnored private var connection: FramedConnection<MacFrame>?
    @ObservationIgnored private var nextID: UInt32 = 1
    @ObservationIgnored private var pingTimer: Timer?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryDelay: Duration = .milliseconds(500)
    @ObservationIgnored private var pendingVolume: Double?
    @ObservationIgnored private var volumeTimer: Timer?
    @ObservationIgnored private var lastVolumeSent = Date.distantPast
    @ObservationIgnored private var endpointLookup: () -> NWEndpoint?
    @ObservationIgnored private var active = false

    init(mac: StoredPairing, deviceID: UUID, deviceName: String, endpointLookup: @escaping () -> NWEndpoint?) {
        self.mac = mac
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.endpointLookup = endpointLookup
    }

    // MARK: Lifecycle

    /// Connects now. Called when the remote appears and when the app returns to the foreground.
    func activate() {
        active = true
        guard connection == nil else { return }
        connect()
    }

    /// Closes the connection when the app leaves the foreground.
    func deactivate() {
        active = false
        retryTask?.cancel()
        tearDown()
    }

    /// Called when Bonjour results change, so a Mac that just appeared is tried at once.
    func endpointsChanged() {
        if active, connection == nil, status != .unpaired { connect() }
    }

    func retryNow() {
        retryDelay = .milliseconds(500)
        retryTask?.cancel()
        if active, connection == nil { connect() }
    }

    private func connect() {
        guard let endpoint = endpointLookup() else {
            status = .unreachable
            scheduleRetry()
            return
        }
        if status != .connected { status = .connecting }
        logic = ClientSessionLogic()
        let parameters = TransportParameters.control(keys: [PreSharedKey(deviceID: deviceID, key: mac.key)])
        let connection = FramedConnection<MacFrame>(to: endpoint, using: parameters)
        self.connection = connection
        connection.start()
        Task { [weak self] in
            for await event in connection.events {
                guard let self, self.connection === connection else { return }
                switch event {
                case .ready: self.sendHello()
                case .frame(let frame): self.handle(frame)
                case .closed(let reason): self.closed(reason)
                }
            }
        }
    }

    private func tearDown() {
        pingTimer?.invalidate()
        volumeTimer?.invalidate()
        connection?.cancel()
        connection = nil
    }

    private func closed(_ reason: CloseReason) {
        tearDown()
        if case .tls = reason, status == .connecting {
            // The handshake was rejected: this Mac no longer has our key.
            status = .unpaired
            return
        }
        if case .updateRequired = status { return }
        status = .unreachable
        scheduleRetry()
    }

    private func scheduleRetry() {
        guard active else { return }
        retryTask?.cancel()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, .seconds(8))
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.active, self.connection == nil else { return }
            self.connect()
        }
    }

    // MARK: Protocol

    private func send(_ message: ClientMessage) -> UInt32 {
        let id = nextID
        nextID &+= 1
        connection?.send(ClientFrame(id: id, message: message))
        return id
    }

    private func sendHello() {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        _ = send(logic.hello(id: nextID, deviceID: deviceID, deviceName: deviceName, appVersion: appVersion))
    }

    private func handle(_ frame: MacFrame) {
        switch logic.handle(frame) {
        case .becameConnected:
            status = .connected
            retryDelay = .milliseconds(500)
            startPing()
        case .close:
            if case .updateRequired(let macIsOlder) = logic.phase { status = .updateRequired(macIsOlder: macIsOlder) }
            tearDown()
        case .none:
            break
        }
    }

    /// Ping every 15 s while connected (protocol §5.3).
    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.send(.ping) }
        }
    }

    // MARK: Commands

    var isConnected: Bool { status == .connected }

    func press(_ command: MediaCommand) {
        guard isConnected else { return }
        _ = send(.command(command))
    }

    func setMuted(_ muted: Bool) {
        guard isConnected else { return }
        logic.applyLocalMute(muted)
        _ = send(.setMuted(muted))
    }

    func sleepMac() {
        guard isConnected else { return }
        _ = send(.sleep)
    }

    /// Sends volume at most every 50 ms while dragging; the last value always goes out (protocol §5.3).
    func setVolume(_ level: Double) {
        guard isConnected else { return }
        let level = min(max(level, 0), 1)
        logic.applyLocalVolume(level)
        pendingVolume = level
        let wait = 0.05 - Date().timeIntervalSince(lastVolumeSent)
        if wait <= 0 {
            flushVolume()
        } else if volumeTimer == nil {
            volumeTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.flushVolume() }
            }
        }
    }

    private func flushVolume() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        guard let level = pendingVolume else { return }
        pendingVolume = nil
        lastVolumeSent = Date()
        _ = send(.setVolume(level))
    }

    // MARK: Previews and snapshot tests

    /// A session with fixed status and state and no network, for snapshot tests (T4) and SwiftUI previews.
    static func preview(mac: StoredPairing, status: Status, state: MacState?, model: String = "Mac15,3") -> RemoteSession {
        let session = RemoteSession(mac: mac, deviceID: UUID(), deviceName: "iPhone") { nil }
        var logic = ClientSessionLogic()
        _ = logic.hello(id: 1, deviceID: UUID(), deviceName: "iPhone", appVersion: "1.0")
        if status == .connected {
            _ = logic.handle(MacFrame(id: 1, message: .helloAck(HelloAck(version: 1, macName: mac.peerName, model: model, appVersion: "1.0"))))
        }
        if let state { _ = logic.handle(MacFrame(id: 2, message: .state(state))) }
        session.logic = logic
        session.status = status
        return session
    }
}
