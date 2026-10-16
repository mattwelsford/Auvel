import AuvelProtocol
import SwiftUI

/// Banner between the dial and the buttons for I10 to I13 and the unpaired case. Empty when all is well.
struct StateBanner: View {
    @Environment(AppModel.self) private var model
    let session: RemoteSession

    var body: some View {
        if let content {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: content.symbol)
                    .font(.title3)
                    .foregroundStyle(content.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title).font(.subheadline.weight(.semibold))
                    Text(content.detail).font(.footnote).foregroundStyle(.secondary)
                    if let action = content.action {
                        Button(action.title, action: action.perform)
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 6)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .contain)
            .transition(.opacity)
        }
    }

    private struct Action {
        let title: String
        let perform: () -> Void
    }

    private struct Content {
        let symbol: String
        let tint: Color
        let title: String
        let detail: String
        var action: Action?
    }

    private var content: Content? {
        let name = session.mac.peerName
        switch session.status {
        case .connecting:
            return nil
        case .unreachable:
            return Content(symbol: "wifi.exclamationmark", tint: .secondary,
                           title: "Can't reach \(name)",
                           detail: "Reconnecting… It may be asleep, on another network, or Auvel may have quit.",
                           action: Action(title: "Try Again") { session.retryNow() })
        case .updateRequired(let macIsOlder):
            return macIsOlder
                ? Content(symbol: "arrow.down.circle", tint: .blue, title: "Update Auvel on your Mac",
                          detail: "This iPhone app needs a newer Auvel for Mac. Choose Check for Updates in its menu.")
                : Content(symbol: "arrow.down.circle", tint: .blue, title: "Update Auvel on this iPhone",
                          detail: "\(name) runs a newer Auvel. Update this app from the App Store.")
        case .unpaired:
            return Content(symbol: "link", tint: .orange, title: "Not paired with \(name) any more",
                           detail: "The Mac removed this iPhone. Pair again from the Mac picker.")
        case .connected:
            guard let state = session.state else { return nil }
            if !state.mediaKeysAllowed {
                return Content(symbol: "hand.raised.fill", tint: .orange, title: "Allow media keys on your Mac",
                               detail: "Open Auvel on the Mac and turn on Accessibility. Volume works now.")
            }
            if !state.volumeSettable {
                return Content(symbol: "speaker.badge.exclamationmark.fill", tint: .orange,
                               title: "\(state.outputName) controls its own volume",
                               detail: "Use the device's buttons, or pick another output on the Mac.")
            }
            return nil
        }
    }
}
