import SwiftUI

struct APIKeySetupView: View {
    @AppStorage("openai_api_key") private var savedKey = ""
    @State private var keyInput = ""
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "key.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                VStack(spacing: 10) {
                    Text("Connect OpenAI")
                        .font(.largeTitle).bold()

                    Text("Window uses GPT-4o to power your goal conversation and daily recommendations. Enter your OpenAI API key to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)

                HStack {
                    Group {
                        if showKey {
                            TextField("sk-...", text: $keyInput)
                        } else {
                            SecureField("sk-...", text: $keyInput)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Your key is stored locally on this device. Get one at platform.openai.com")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                savedKey = keyInput.trimmingCharacters(in: .whitespaces)
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidKey ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValidKey)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    private var isValidKey: Bool {
        keyInput.trimmingCharacters(in: .whitespaces).hasPrefix("sk-")
    }
}
