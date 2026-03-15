import SwiftUI

struct PermissionsView: View {
    let onContinue: () -> Void

    @StateObject private var screenTime = ScreenTimeService.shared
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                VStack(spacing: 10) {
                    Text("See Your Patterns")
                        .font(.largeTitle).bold()

                    Text("Window reads your Screen Time data to learn when you focus best and when you drift — so every recommendation actually fits your life.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            VStack(spacing: 14) {
                Button {
                    Task {
                        isRequesting = true
                        await screenTime.requestAuthorization()
                        isRequesting = false
                        onContinue()
                    }
                } label: {
                    Label(
                        isRequesting ? "Requesting access…" : "Allow Screen Time Access",
                        systemImage: "chart.bar"
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
}
