import AuvelProtocol
import Foundation
import Network
import dnssd

/// A Mac running Auvel, seen on this network (protocol §2).
struct DiscoveredMac: Identifiable, Hashable {
    let id: UUID
    let name: String
    let model: String
    let protocolVersion: Int
    let endpoint: NWEndpoint
}

/// Browses one Bonjour service type. Reports Macs by their TXT `id` and whether Local Network access is denied.
@MainActor
final class BonjourBrowser {
    private(set) var macs: [UUID: DiscoveredMac] = [:]
    private(set) var localNetworkDenied = false
    var onChange: () -> Void = {}

    private let serviceType: String
    private var browser: NWBrowser?

    init(serviceType: String) {
        self.serviceType = serviceType
    }

    func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = false
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.stateChanged(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated { self?.update(results) }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        macs = [:]
        onChange()
    }

    /// Restarts after the user returns from Settings, so a newly granted permission takes effect.
    func restart() {
        stop()
        start()
    }

    private func stateChanged(_ state: NWBrowser.State) {
        var denied = false
        switch state {
        case .waiting(let error), .failed(let error):
            if case .dns(let code) = error, code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) { denied = true }
        default:
            break
        }
        if denied != localNetworkDenied {
            localNetworkDenied = denied
            onChange()
        }
    }

    private func update(_ results: Set<NWBrowser.Result>) {
        var found: [UUID: DiscoveredMac] = [:]
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint,
                  case .bonjour(let txt) = result.metadata,
                  let idString = txt[Bonjour.TXTKey.macID], let id = UUID(uuidString: idString) else { continue }
            found[id] = DiscoveredMac(
                id: id,
                name: name,
                model: txt[Bonjour.TXTKey.model] ?? "",
                protocolVersion: Int(txt[Bonjour.TXTKey.protocolVersion] ?? "") ?? 1,
                endpoint: result.endpoint
            )
        }
        macs = found
        onChange()
    }
}
