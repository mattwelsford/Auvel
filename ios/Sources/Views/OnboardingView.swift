import SwiftUI

/// I01 first launch and I20 at accessibility sizes: three steps, one primary action, pinned buttons.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 9, y: 6)
                    .padding(.top, 40)
                    .accessibilityHidden(true)
                Text("Control your Mac from here")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 26)
                Text("Pause, skip and change volume from across the room. Auvel needs its free companion app on your Mac.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 18) {
                    StepRow(number: 1, title: "Install Auvel for Mac", detail: "From getauvel.com/mac or Homebrew")
                    StepRow(number: 2, title: "Allow media key control", detail: "A one-time switch in System Settings")
                    StepRow(number: 3, title: "Enter the code it shows", detail: "Pairs this iPhone with your Mac")
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                ShareLink(item: AppModel.macDownloadURL,
                          subject: Text("Auvel for Mac"),
                          message: Text("Install Auvel on this Mac: \(AppModel.macDownloadURL.absoluteString)")) {
                    Text("Send Mac Link…")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Color(.label))
                .foregroundStyle(Color(.systemBackground))
                .accessibilityHint("Opens the share sheet.")

                Button("It's Installed") { model.hasSeenOnboarding = true }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(.bar)
        }
    }
}

private struct StepRow: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.goldText)
                .frame(width: 30, height: 30)
                .background(.fill.tertiary, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number) of 3. \(title). \(detail).")
    }
}
