import Foundation
import Network
import Security

/// One pre-shared key: the pairing key `K` and the iPhone's device ID as identity (protocol §7).
public struct PreSharedKey: Sendable {
    public let identity: Data
    public let key: Data

    public init(identity: Data, key: Data) {
        self.identity = identity
        self.key = key
    }

    public init(deviceID: UUID, key: Data) {
        self.init(identity: withUnsafeBytes(of: deviceID.uuid) { Data($0) }, key: key)
    }
}

public enum TransportParameters {
    /// TLS_PSK_WITH_AES_128_GCM_SHA256 (RFC 5487), the suite used in Apple's Network.framework peer-to-peer sample.
    static let pskCipherSuite = tls_ciphersuite_t(rawValue: 0x00A8)!

    /// Control connection parameters. The iPhone passes its one key. The Mac passes every paired iPhone's key
    /// and the TLS stack selects by the identity the iPhone sends.
    public static func control(keys: [PreSharedKey], tlsVersion: tls_protocol_version_t = .TLSv12) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        for psk in keys {
            let key = psk.key.withUnsafeBytes { DispatchData(bytes: $0) }
            let identity = psk.identity.withUnsafeBytes { DispatchData(bytes: $0) }
            sec_protocol_options_add_pre_shared_key(options, key as __DispatchData, identity as __DispatchData)
        }
        sec_protocol_options_set_min_tls_protocol_version(options, tlsVersion)
        sec_protocol_options_set_max_tls_protocol_version(options, tlsVersion)
        if tlsVersion == .TLSv12 {
            sec_protocol_options_append_tls_ciphersuite(options, pskCipherSuite)
        }

        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 15
        tcp.noDelay = true

        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = false
        return parameters
    }

    /// Pairing connection parameters: plain TCP. Pairing frames carry no secrets (protocol §6).
    public static func pairing() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.includePeerToPeer = false
        return parameters
    }
}
