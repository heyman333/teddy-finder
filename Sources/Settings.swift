import SwiftUI
import AudioToolbox

/// 설정값. @AppStorage 키를 한 곳에 모아 둔다.
enum Pref {
    static let haptics = "haptics", sound = "sound", confetti = "confetti", sensitivity = "sensitivity"

    /// 민감도 0(깐깐) 1(보통) 2(너그러움) → Tracker의 찾음/유지 기준.
    static func thresholds(_ level: Int) -> (enter: Float, stay: Float) {
        switch level { case 0: (0.6, 0.3); case 2: (0.4, 0.2); default: (0.5, 0.25) }
    }

    /// 찾았을 때 진동·소리. 설정에 따라.
    static func celebrate() {
        let d = UserDefaults.standard
        if d.object(forKey: haptics) as? Bool ?? true { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        if d.object(forKey: sound) as? Bool ?? true { AudioServicesPlaySystemSound(1016) }   // 짧은 "짹" 소리
    }
}

struct SettingsSheet: View {
    let store: ItemStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Pref.haptics) private var haptics = true
    @AppStorage(Pref.sound) private var sound = true
    @AppStorage(Pref.confetti) private var confetti = true
    @AppStorage(Pref.sensitivity) private var sensitivity = 1
    @State private var confirmClear = false

    private var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }
    private var added: [Item] { store.extras.map(Item.known) + store.custom.map(Item.custom) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // iOS 자체 앱별 언어 설정을 연다(앱 안에서 따로 바꾸는 것보다 확실하고 재시작도 iOS가 처리).
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        HStack {
                            Label("Language", systemImage: "globe")
                            Spacer()
                            Text(languageName).foregroundStyle(Color.ink.opacity(0.6))
                            Image(systemName: "arrow.up.forward.app").foregroundStyle(Color.ink.opacity(0.6))
                        }
                    }
                } footer: {
                    Text("Opens iPhone Settings. If Language isn't there, add both Korean and English under General › Language & Region.")
                }
                .listRowBackground(Color.cream)

                Section("When Teddy finds it") {
                    Toggle(isOn: $haptics) { Label("Vibration", systemImage: "iphone.radiowaves.left.and.right") }
                    Toggle(isOn: $sound) { Label("Sound", systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $confetti) { Label("Confetti", systemImage: "party.popper.fill") }
                }
                .listRowBackground(Color.cream)

                Section {
                    Picker(selection: $sensitivity) {
                        Text("Careful").tag(0)
                        Text("Normal").tag(1)
                        Text("Eager").tag(2)
                    } label: { Label("Sensitivity", systemImage: "scope") }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Sensitivity")
                } footer: {
                    Text("Missing things? Try Eager. Finding the wrong things? Try Careful.")
                }
                .listRowBackground(Color.cream)

                Section("My items") {
                    if added.isEmpty {
                        Text("Nothing added yet. Tap + to add something.").foregroundStyle(Color.ink.opacity(0.6))
                    }
                    ForEach(added) { item in
                        HStack(spacing: 10) {
                            if case .custom(let c) = item, let img = store.thumbnail(c) {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 30, height: 30)
                                    .clipShape(Circle()).overlay(Circle().stroke(Color.ink, lineWidth: 2))
                            } else {
                                Text(item.emoji).frame(width: 30)
                            }
                            Text(item.label)
                            Spacer()
                            if case .custom = item { Text("Taught").font(.caption.weight(.bold)).foregroundStyle(Color.ink.opacity(0.5)) }
                        }
                    }
                    .onDelete { idx in idx.map { added[$0] }.forEach(store.remove) }
                }
                .listRowBackground(Color.cream)

                Section {
                    Button(role: .destructive) { confirmClear = true } label: {
                        Label("Delete last-found photos", systemImage: "trash")
                            .foregroundStyle(Color(red: 0.75, green: 0.2, blue: 0.2))
                    }
                    // AGPL-3.0: 앱 안에서 소스 위치를 알려야 한다.
                    Link(destination: URL(string: "https://github.com/heyman333/teddy-finder")!) {
                        HStack {
                            Label("Source code (AGPL-3.0)", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app").foregroundStyle(Color.ink.opacity(0.6))
                        }
                    }
                    Link(destination: URL(string: "https://heyman333.github.io/teddy-finder/privacy.html")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app").foregroundStyle(Color.ink.opacity(0.6))
                        }
                    }
                } footer: {
                    Text("When Teddy finds something, it saves a photo of the spot. You see it when you tap \"Can't find it?\". Everything stays on this iPhone.")
                }
                .listRowBackground(Color.cream)
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .tint(Color.honey)
            .foregroundStyle(Color.ink)
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.heavy) }
            }
            .confirmationDialog(Text("Delete all last-found photos?"), isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { LastSeen.removeAll() }
            }
        }
    }
}
