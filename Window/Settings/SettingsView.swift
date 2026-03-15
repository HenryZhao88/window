import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_api_key") private var savedKey = ""
    @State private var keyInput = ""
    @State private var showKey = false
    @State private var tapCount = 0
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group {
                            if showKey {
                                TextField("sk-...", text: $keyInput)
                            } else {
                                SecureField("sk-...", text: $keyInput)
                            }
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !keyInput.isEmpty {
                        Button("Save Key") {
                            savedKey = keyInput.trimmingCharacters(in: .whitespaces)
                            keyInput = ""
                        }
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        Label(
                            savedKey.isEmpty ? "Not set" : "Connected",
                            systemImage: savedKey.isEmpty ? "xmark.circle" : "checkmark.circle.fill"
                        )
                        .foregroundStyle(savedKey.isEmpty ? .red : .green)
                        .font(.caption)
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Required for recommendations and onboarding. Get your key at platform.openai.com")
                }

                Section {
                    Text("Window v1.0 MVP")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .onTapGesture {
                            tapCount += 1
                            if tapCount >= 5 {
                                tapCount = 0
                                showDebug = true
                            }
                        }
                } footer: {
                    Text("Tap the version number 5 times to open Debug Panel")
                        .font(.caption2)
                }
            }
            .navigationTitle("Settings")
            #if DEBUG
            .sheet(isPresented: $showDebug) {
                DebugPanelView()
            }
            #endif
        }
    }
}
