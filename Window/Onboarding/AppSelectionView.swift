import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    let onContinue: () -> Void

    @StateObject private var screenTime = ScreenTimeService.shared
    @State private var selection: FamilyActivitySelection
    @State private var isPickerPresented = false

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        _selection = State(initialValue: ScreenTimeService.shared.savedSelection() ?? FamilyActivitySelection())
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 54))
                    .foregroundStyle(.blue)

                Text("Choose what Window should watch")
                    .font(.title2.bold())

                Text("Pick distracting apps or categories so Window can notice when your attention drifts and suggest a better next move.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)

                Text(selectionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 14) {
                Button("Choose Apps and Categories") {
                    isPickerPresented = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button("Continue") {
                    screenTime.startMonitoring(selection: selection)
                    onContinue()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button("Skip for now") {
                    onContinue()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
    }

    private var selectionSummary: String {
        let appCount = selection.applicationTokens.count
        let categoryCount = selection.categoryTokens.count
        let domainCount = selection.webDomainTokens.count
        let totalCount = appCount + categoryCount + domainCount

        if totalCount == 0 {
            return "No apps selected yet."
        }

        return "\(appCount) apps, \(categoryCount) categories, \(domainCount) websites selected"
    }
}
