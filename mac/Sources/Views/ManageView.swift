import AuvelTransport
import SwiftUI

/// Remove paired iPhones. Removing one deletes its key, so it can no longer connect (protocol §7.4).
struct ManageView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.pairedPhones.isEmpty {
                ContentUnavailableView("No paired iPhones", systemImage: "iphone",
                                       description: Text("Choose Pair an iPhone… in the Auvel menu."))
            } else {
                List(model.pairedPhones) { phone in
                    HStack {
                        Image(systemName: "iphone").foregroundStyle(.secondary).accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(phone.peerName)
                            Text(model.isConnected(phone) ? "Connected" : "Paired \(phone.pairedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove", role: .destructive) { model.remove(phone) }
                            .accessibilityLabel("Remove \(phone.peerName)")
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 160)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear(perform: bringToFront)
    }
}
