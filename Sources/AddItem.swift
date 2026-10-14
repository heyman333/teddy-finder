import SwiftUI
import PhotosUI
import AVFoundation

/// "+" 시트: 이름 입력 → 아는 물건이면 바로 찾기, 모르면 사진으로 가르치기.
struct AddItemSheet: View {
    let store: ItemStore
    let onPick: (Item) -> Void
    @Environment(\.dismiss) private var dismiss

    private enum Step { case name, known(Item), teach }
    @State private var step = Step.name
    @State private var name = ""
    @State private var photos: [UIImage] = []
    @State private var picked: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var studying = false
    @State private var failed = false
    @State private var personMode = false   // 여자친구·남자친구 등 사람을 가르치는 중
    @FocusState private var typing: Bool
    private static let tile: CGFloat = 104
    private static let examples: [LocalizedStringKey] = ["AirPods", "Car keys", "Wallet", "Teddy bear"]

    var body: some View {
        VStack(spacing: 18) {
            switch step {
            case .name: nameStep
            case .known(let item): knownStep(item)
            case .teach: teachStep
            }
        }
        .foregroundStyle(Color.ink)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.paper)
        .animation(.snappy, value: photos.count)
        .presentationDetents([.large])
        .photosPicker(isPresented: $showLibrary, selection: $picked, maxSelectionCount: max(1, 5 - photos.count), matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { if let img = $0 { photos.append(img) } }.ignoresSafeArea()
        }
        .onChange(of: picked) { _, items in
            Task {
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { photos.append(img) }
                }
                picked = []
            }
        }
    }

    // MARK: 1. 이름

    private var nameStep: some View {
        VStack(spacing: 18) {
            Image("mascot_search").resizable().scaledToFit().frame(width: 150).padding(.top, 20)
            Text("What should Teddy look for?")
                .font(.system(.title2, design: .rounded).weight(.black)).multilineTextAlignment(.center)
            TextField("e.g. AirPods", text: $name)
                .font(.title3.weight(.bold))
                .padding(.horizontal, 18).padding(.vertical, 14)
                .sticker(.cream, RoundedRectangle(cornerRadius: 18, style: .continuous))
                .focused($typing)
                .submitLabel(.next)
                .onSubmit(next)
            HStack(spacing: 8) {
                ForEach(Self.examples.indices, id: \.self) { i in
                    Button { name = String(localized: exampleResource(i)); next() } label: {
                        Text(Self.examples[i]).font(.caption.weight(.heavy)).padding(.horizontal, 10).padding(.vertical, 7)
                    }
                    .buttonStyle(.plain).sticker()
                }
            }
            Spacer()
            bigButton("Next", enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, action: next)
        }
        .onAppear { typing = true }
    }

    private func exampleResource(_ i: Int) -> String.LocalizationValue {
        ["AirPods", "Car keys", "Wallet", "Teddy bear"][i]
    }

    private func next() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        typing = false
        withAnimation(.snappy) { step = store.known(n).map(Step.known) ?? .teach }
    }

    // MARK: 2a. 이미 아는 물건

    private func knownStep(_ item: Item) -> some View {
        VStack(spacing: 18) {
            Image("mascot_found").resizable().scaledToFit().frame(width: 170).padding(.top, 20)
            Text("Teddy already knows this!")
                .font(.system(.title2, design: .rounded).weight(.black))
            Text("\(item.emoji) \(item.label)")
                .font(.title3.weight(.heavy))
                .padding(.horizontal, 18).padding(.vertical, 10).sticker(.honey)
            Spacer()
            if item == .known(.person) {
                // 재미 요소: 특정 사람은 사진으로 "오늘 옷차림"을 가르친다.
                bigButton("Teach Teddy who it is 💕") { personMode = true; withAnimation(.snappy) { step = .teach } }
                Button { onPick(item); dismiss() } label: {
                    Text("Just find anyone").font(.headline.weight(.heavy)).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            } else {
                bigButton("Start looking") { onPick(item); dismiss() }
            }
        }
    }

    // MARK: 2b. 사진으로 가르치기

    private var teachStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("mascot_search").resizable().scaledToFit().frame(width: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Teddy hasn't met \(name) yet")
                        .font(.system(.title3, design: .rounded).weight(.black))
                    Text(personMode ? "Teddy will remember today's outfit" : "Show it a few close-up photos")
                        .font(.subheadline.weight(.semibold)).opacity(0.75)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                if personMode {
                    Label("Full-body photos, same outfit as now", systemImage: "figure.stand")
                    Label("Ask them first, it's a game for two 😉", systemImage: "heart")
                } else {
                    Label("Fill the photo with the item", systemImage: "viewfinder")
                    Label("3 photos, different angles and places", systemImage: "camera.rotate")
                }
            }
            .font(.subheadline.weight(.bold))
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .sticker(.cream, RoundedRectangle(cornerRadius: 18, style: .continuous))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(photos.indices, id: \.self) { i in
                    Image(uiImage: photos[i]).resizable().scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity).frame(height: Self.tile).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.ink, lineWidth: 3))
                        .overlay(alignment: .topTrailing) {
                            Button { photos.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Color.ink, Color.cream)
                            }
                            .padding(4)
                        }
                }
                if photos.count < 5 {
                    addTile
                }
            }

            if failed {
                Text("Teddy couldn't learn from these. Try clearer close-ups.")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color(red: 0.7, green: 0.2, blue: 0.2))
            }
            Spacer()
            if studying {
                HStack { Spacer(); ProgressView(); Text("Teddy is studying…").font(.headline.weight(.heavy)); Spacer() }
                    .padding(.vertical, 14)
            } else {
                bigButton(photos.count >= 3 ? "Teach Teddy" : "Teach Teddy (\(photos.count)/3)", enabled: !photos.isEmpty, action: teach)
            }
        }
    }

    /// 사진 추가 칸: 카메라 있으면 찍기 / 앨범에서 고르기 메뉴.
    private var addTile: some View {
        Menu {
            if AVCaptureDevice.default(for: .video) != nil {   // 시뮬레이터는 카메라 없음
                Button { showCamera = true } label: { Label("Take a photo", systemImage: "camera") }
            }
            // PhotosPicker를 Menu 안에 두면 메뉴와 함께 닫혀버려서, 버튼으로 시트 바깥 picker를 연다.
            Button { showLibrary = true } label: { Label("Choose from Photos", systemImage: "photo.on.rectangle") }
        } label: {
            Image(systemName: "plus").font(.title2.weight(.black)).foregroundStyle(Color.ink)
                .frame(minWidth: 0, maxWidth: .infinity).frame(height: Self.tile)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cream.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.ink, style: StrokeStyle(lineWidth: 3, dash: [7, 5])))
        }
        .frame(maxWidth: .infinity)   // Menu는 라벨 크기를 줄여버려서 바깥에서 한 번 더 펼친다
        .accessibilityLabel(Text("Add photo"))
    }

    private func teach() {
        studying = true; failed = false
        Task {
            let item = await store.teach(name: name, photos: photos, person: personMode)
            studying = false
            if let item { onPick(item); dismiss() } else { failed = true }
        }
    }

    private func bigButton(_ title: LocalizedStringKey, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline.weight(.heavy)).foregroundStyle(Color.cream)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .sticker(.bear, RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}

/// 시스템 카메라로 한 장 찍기.
struct CameraPicker: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage); p.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { done(nil); p.dismiss(animated: true) }
    }
}
