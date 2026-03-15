import SwiftUI

struct PermissionsView: View {
    let onContinue: () -> Void

    @StateObject private var screenTime = ScreenTimeService.shared
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                permissionRow(
                    icon: "chart.bar.doc.horizontal.fill",
                    color: .blue,
                    title: "Screen Time",
                    description: "See when you focus best and when you drift."
                )

                Divider().padding(.horizontal, 40)

                permissionRow(
                    icon: "bell.badge.fill",
                    color: .orange,
                    title: "Notifications",
                    description: "Get nudged when a productive window opens up."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    Task {
                        isRequesting = true
                        await screenTime.requestAuthorization()
                        await NotificationScheduler.shared.requestPermission()
                        isRequesting = false
                        onContinue()
                    }
                } label: {
                    Label(
                        isRequesting ? "Requesting access…" : "Allow Access",
                        systemImage: "lock.open.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isRequesting)

                Button("Skip for now") { onContinue() }
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func permissionRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(color)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
