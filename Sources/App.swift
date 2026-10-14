import SwiftUI
import PhotosUI
import AVFoundation
import Vision

@main
struct TeddyFinderApp: App {
    @State private var splash = true
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if splash {
                    SplashView { withAnimation(.easeOut(duration: 0.35)) { splash = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
    }
}

/// 시작 화면(정적, Info.plist) 다음에 이어지는 1.5초짜리 애니메이션.
/// 곰은 시작 화면과 같은 자리·크기(가운데 170pt)에서 출발해서 화면이 바뀌는 티가 안 난다.
struct SplashView: View {
    let done: () -> Void
    @State private var pop = false
    @State private var paws = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            // 발자국이 아래에서 곰 쪽으로 콩콩
            ForEach(0..<4) { i in
                Image(systemName: "pawprint.fill").font(.system(size: 22))
                    .foregroundStyle(Color.bear.opacity(0.35))
                    .rotationEffect(.degrees(i.isMultiple(of: 2) ? -15 : 15))
                    .offset(x: i.isMultiple(of: 2) ? -22 : 22, y: 360 - CGFloat(i) * 50)
                    .opacity(paws > i ? 1 : 0)
                    .scaleEffect(paws > i ? 1 : 0.3)
            }
            Image("splash_bear").resizable().scaledToFit().frame(width: 170, height: 170)
                .scaleEffect(pop ? 1.08 : 1)
                .rotationEffect(.degrees(pop ? -6 : 0))
            Text("TeddyFinder")
                .font(.system(.title, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .sticker()
                .rotationEffect(.degrees(-4))
                .offset(y: 130)
                .scaleEffect(pop ? 1 : 0.4)
                .opacity(pop ? 1 : 0)
        }
        .task {
            if reduceMotion { pop = true; paws = 4; try? await Task.sleep(for: .seconds(0.8)); done(); return }
            for i in 1...4 {
                try? await Task.sleep(for: .seconds(0.12))
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { paws = i }
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.6)) { pop = true }
            try? await Task.sleep(for: .seconds(0.9))
            done()
        }
    }
}

// 스티커 카툰 팔레트: 곰돌이에 맞춘 꿀·복숭아 톤 + 크림 + 검정 잉크. 색은 전부 여기서만 바꾼다.
extension Color {
    static let paper = Color(red: 0.99, green: 0.89, blue: 0.80)   // 배경 (복숭아)
    static let honey = Color(red: 0.96, green: 0.69, blue: 0.30)   // 선택·찾음 강조 (꿀)
    static let blush = Color(red: 0.98, green: 0.75, blue: 0.78)   // 보조 버튼 (분홍)
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.90)
    static let ink   = Color(red: 0.10, green: 0.10, blue: 0.09)
    static let bear  = Color(red: 0.40, green: 0.26, blue: 0.16)
}

/// 스티커 룩: 크림 바탕 + 두꺼운 잉크 외곽선 + 딱딱한 오프셋 그림자.
struct Sticker: ViewModifier {
    var fill: Color = .cream
    var shape: AnyShape = AnyShape(Capsule())
    func body(content: Content) -> some View {
        content
            .background(shape.fill(fill))
            .background(shape.fill(Color.ink).offset(x: 4, y: 4))   // 뒤에 붙는 background가 더 뒤 레이어
            .overlay(shape.stroke(Color.ink, lineWidth: 3))
    }
}
extension View {
    func sticker(_ fill: Color = .cream, _ shape: some Shape = Capsule()) -> some View {
        modifier(Sticker(fill: fill, shape: AnyShape(shape)))
    }
}

struct ContentView: View {
    @State private var store = ItemStore()
    @State private var target: Item = .known(.remote)
    @State private var refs: [VNFeaturePrintObservation] = []   // 가르친 물건이면 등록 특징값
    @State private var showAdd = false
    @State private var showSettings = false
    @AppStorage(Pref.confetti) private var confetti = true
    @AppStorage(Pref.sensitivity) private var sensitivity = 1
    @State private var bursts = 0                  // 폭죽 트리거 카운터
    @State private var photo: UIImage?        // 시뮬레이터(카메라 없음)용 대체 입력
    @State private var picked: PhotosPickerItem?
    private let hasCamera = AVCaptureDevice.default(for: .video) != nil
    private let detector = Detector()
    @State private var tracker = Tracker()   // 흔들리는 탐지 → 안정된 찾음 상태 + 박스 (Tracker.swift)
    private var found: Bool { tracker.found }
    private var box: [CGRect] { tracker.box.map { [$0] } ?? [] }
    @State private var showLastSeen = false

    var body: some View {
        ZStack {
            if hasCamera {
                CameraView(item: (target, refs), onResult: frame).ignoresSafeArea()
                Boxes(boxes: found ? box : [], label: target.label)
                    .opacity(tracker.stale() ? 0.55 : 1)   // 잠깐 놓쳐도 박스는 남겨두고 흐리게
                    .animation(.easeOut(duration: 0.2), value: tracker.stale())
                    .ignoresSafeArea()
            } else {
                Doodles().ignoresSafeArea()
                PhotoMode(image: photo, boxes: box, label: target.label)
            }
            Confetti(trigger: bursts).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 14) {
                HStack(alignment: .top) {
                    TitleSticker()
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill").font(.headline).foregroundStyle(Color.ink)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain).sticker(.cream, Circle())
                    .accessibilityLabel(Text("Settings"))
                    Compass(pointing: needle)
                }
                Spacer()
                if !found {
                    HStack {
                        Spacer()
                        Button { showLastSeen = true } label: {
                            Label("Can't find it?", systemImage: "questionmark.circle.fill")
                                .font(.subheadline.weight(.heavy)).foregroundStyle(Color.ink)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                        .buttonStyle(.plain).sticker(.blush)
                        .rotationEffect(.degrees(3))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                StatusCard(found: found, label: target.label).onTapGesture { bursts += 1 }  // 곰 톡 치면 폭죽
                TargetChips(store: store, target: $target, onAdd: { showAdd = true })
                if !hasCamera && Demo.photo == nil {
                    PhotosPicker("Pick a photo", selection: $picked, matching: .images)
                        .font(.headline).foregroundStyle(Color.cream)
                        .padding(.horizontal, 18).padding(.vertical, 10).sticker(.bear)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(hasCamera ? Color.black : Color.paper)
        .animation(.spring(duration: 0.4, bounce: 0.5), value: found)
        .sheet(isPresented: $showLastSeen) { LastSeenSheet(target: target) }
        .sheet(isPresented: $showSettings) { SettingsSheet(store: store) }
        .sheet(isPresented: $showAdd) {
            AddItemSheet(store: store) { item in withAnimation(.snappy) { target = item } }
        }
        .onChange(of: found) { _, now in
            guard now else { return }
            if confetti { bursts += 1 }
            Pref.celebrate()
        }
        .onChange(of: target) { _, t in
            if case .custom(let c) = t { refs = store.refs(c) } else { refs = [] }
            detector.item = (t, refs)
            tracker = freshTracker()
            if let photo { detect(photo) }
        }
        .onChange(of: sensitivity) { _, _ in tracker = freshTracker() }
        .onAppear {
            tracker = freshTracker()
            if let img = Demo.photo { photo = img; detect(img) }
        }
        .onChange(of: picked) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return }
                photo = img
                detect(img)
            }
        }
    }
}

extension ContentView {
    /// 민감도 설정을 반영한 새 Tracker.
    func freshTracker() -> Tracker {
        var t = Tracker()
        (t.enterConf, t.stayConf) = Pref.thresholds(sensitivity)
        return t
    }

    /// 찾았으면 화면 중앙에서 물건 쪽 각도(0 = 위, 시계방향). 못 찾았으면 nil → 나침반이 빙글빙글.
    var needle: Angle? {
        guard found, let b = tracker.box else { return nil }
        let (dx, dy): (CGFloat, CGFloat) = hasCamera
            ? (b.midX - UIScreen.main.bounds.midX, b.midY - UIScreen.main.bounds.midY)  // 카메라: 뷰 좌표
            : (b.midX - 0.5, 0.5 - b.midY)                                              // 사진: Vision 정규화(원점 좌하단)
        return .radians(atan2(dx, -dy))
    }

    /// 사진 모드: 한 장이라 바로 판정하고, 찾았으면 기록.
    func detect(_ img: UIImage) {
        let t = target
        detector.detect(img) { found in
            var hits = found
            if case .custom = t, let demo = Demo.hits { hits = demo }   // 시뮬레이터는 특징값 비교를 못 돌려서 Mac에서 계산한 결과를 주입
            if tracker.single(hits), let b = tracker.box { LastSeen.save(t, LastSeen.stamp(img, box: b)) }
        }
    }

    /// 카메라 프레임마다 호출.
    func frame(_ hits: [Hit], snapshot: @escaping () -> UIImage?) {
        if tracker.update(hits) {
            let t = target
            DispatchQueue.global(qos: .utility).async { if let img = snapshot() { LastSeen.save(t, img) } }   // 다음에 "지난번엔 여기!"용
        }
    }
}

/// 왼쪽 위 앱 이름 스티커.
struct TitleSticker: View {
    var body: some View {
        Label("TeddyFinder", systemImage: "pawprint.fill")
            .font(.system(.headline, design: .rounded).weight(.black))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .sticker()
            .rotationEffect(.degrees(-4))
    }
}

/// 스티커 나침반. pointing이 nil이면 빙글빙글 탐색, 값이 있으면 그 방향(찾은 물건)을 가리킨다.
struct Compass: View {
    let pointing: Angle?
    var body: some View {
        TimelineView(.animation) { ctx in
            // 기준시각(2001년~) 그대로 쓰면 각도가 10^11도라 회전 보간이 망가진다. 1시간 단위로 잘라 작게 유지.
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            let spin = Angle.degrees((t * 120 + sin(t * 3) * 25).truncatingRemainder(dividingBy: 360))   // 두리번거리듯 돌다 멈칫
            ZStack {
                Circle().fill(Color.cream)
                ForEach(0..<4) { i in   // 동서남북 점
                    Circle().fill(Color.ink).frame(width: 5, height: 5)
                        .offset(y: -27).rotationEffect(.degrees(Double(i) * 90))
                }
                Needle().rotationEffect(pointing ?? spin)
                    .animation(.spring(duration: 0.5, bounce: 0.4), value: pointing)
                Image(systemName: "pawprint.fill").font(.system(size: 9)).foregroundStyle(Color.cream)
                    .padding(4).background(Circle().fill(Color.bear)).overlay(Circle().stroke(Color.ink, lineWidth: 2))
            }
            .frame(width: 70, height: 70)
            .sticker(.cream, Circle())
        }
    }
}

struct Needle: View {
    var body: some View {
        VStack(spacing: 0) {
            Tri().fill(Color(red: 0.93, green: 0.45, blue: 0.45)).overlay(Tri().stroke(Color.ink, lineWidth: 2))
            Tri().rotation(.degrees(180)).fill(Color.paper).overlay(Tri().rotation(.degrees(180)).stroke(Color.ink, lineWidth: 2))
        }
        .frame(width: 14, height: 50)
    }
    struct Tri: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
        }
    }
}

/// 카키 배경에 흩뿌린 발자국·별 낙서. 자리는 고정(매번 랜덤이면 화면 갱신마다 튄다).
struct Doodles: View {
    static let items: [(String, CGFloat, CGFloat, Double, CGFloat)] = [   // 심볼, x, y(비율), 회전, 크기
        ("pawprint.fill", 0.12, 0.20, -20, 26), ("pawprint.fill", 0.22, 0.27, -10, 20), ("star.fill", 0.85, 0.22, 15, 22),
        ("sparkle", 0.70, 0.33, 0, 18), ("pawprint.fill", 0.80, 0.42, 25, 24), ("heart.fill", 0.15, 0.45, -15, 18),
        ("star.fill", 0.40, 0.15, -8, 14), ("sparkle", 0.28, 0.58, 0, 16), ("pawprint.fill", 0.88, 0.60, 30, 18),
    ]
    var body: some View {
        GeometryReader { g in
            ForEach(Self.items.indices, id: \.self) { i in
                let (name, x, y, deg, size) = Self.items[i]
                Image(systemName: name).font(.system(size: size))
                    .foregroundStyle(Color.honey.opacity(0.35))
                    .rotationEffect(.degrees(deg))
                    .position(x: g.size.width * x, y: g.size.height * y)
            }
        }
    }
}

/// 찾을 물건 칩 줄. 화면 맨 아래라 한 손 엄지로 닿는다.
struct TargetChips: View {
    let store: ItemStore
    @Binding var target: Item
    let onAdd: () -> Void

    var body: some View {
        // "+"는 스크롤 밖에 고정: 칩이 많아져도 엄지 자리에 항상 있다.
        HStack(spacing: 8) {
            Button(action: onAdd) {
                Image(systemName: "plus").font(.subheadline.weight(.black)).foregroundStyle(Color.ink)
                    .frame(width: 42, height: 40)
            }
            .buttonStyle(.plain).sticker(.blush)
            .accessibilityLabel(Text("Add something to find"))
            .zIndex(1)   // 스크롤되는 칩이 "+" 위로 지나가지 않게

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.all) { t in chip(t).id(t.id) }
                    }
                    .padding(.horizontal, 6).padding(.vertical, 6)
                }
                .scrollClipDisabled()
                // 좌우만 잘라서 칩이 "+" 뒤로 비치지 않게. 위아래는 스티커 그림자가 보이도록 여유.
                .mask(Rectangle().padding(.vertical, -30))
                .onChange(of: target) { _, t in withAnimation { proxy.scrollTo(t.id, anchor: .center) } }
            }
        }
    }

    private func chip(_ t: Item) -> some View {
        let on = t == target
        let removable: Bool = { if case .known(let k) = t { return !Target.presets.contains(k) }; return true }()
        return Button { withAnimation(.snappy) { target = t } } label: {
            HStack(spacing: 6) {
                if case .custom(let c) = t, let img = store.thumbnail(c) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 24, height: 24)
                        .clipShape(Circle()).overlay(Circle().stroke(Color.ink, lineWidth: 2))
                } else {
                    Text(t.emoji)
                }
                Text(t.label)
            }
            .font(.subheadline.weight(.heavy))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .foregroundStyle(Color.ink)
        }
        .buttonStyle(.plain)
        .sticker(on ? .honey : .cream)
        .rotationEffect(.degrees(on ? -3 : 0))
        .contextMenu {   // 길게 눌러 지우기 (기본 프리셋은 못 지움)
            if removable {
                Button(role: .destructive) {
                    if on { target = .known(.remote) }
                    store.remove(t)
                } label: { Label("Remove", systemImage: "trash") }
            }
        }
    }
}

/// 하단 마스코트 카드. 찾으면 올리브색으로 바뀌며 통통 튄다.
struct StatusCard: View {
    let found: Bool
    let label: String
    static let hints: [LocalizedStringKey] = [
        "Move slowly and look around",
        "Check between the sofa cushions",
        "Peek under the blanket",
        "Look around the coffee table",
        "Check your bag and pockets",
    ]
    @State private var bob = false

    var body: some View {
        HStack(spacing: 14) {
            Image(found ? "mascot_found" : "mascot_search")
                .resizable().scaledToFit().frame(width: 90, height: 90)
                .scaleEffect(found ? 1.12 : 1)
                .rotationEffect(.degrees(found ? -6 : 0))
                .offset(y: bob ? -4 : 3)   // 숨쉬듯 둥실둥실
                .animation(.easeInOut(duration: 1.1).repeatForever(), value: bob)
                .onAppear { bob = true }
            VStack(alignment: .leading, spacing: 4) {
                (found ? Text("Found it!!") : Text("Looking for \(label)…"))
                    .font(.system(.title2, design: .rounded).weight(.black))
                if found {
                    Text("Look inside the box 👀").font(.subheadline.weight(.semibold)).opacity(0.75)
                } else {
                    // 4초마다 다음 힌트
                    TimelineView(.periodic(from: .now, by: 4)) { ctx in
                        let i = Int(ctx.date.timeIntervalSinceReferenceDate / 4) % Self.hints.count
                        Text(Self.hints[i]).font(.subheadline.weight(.semibold)).opacity(0.75)
                            .id(i).transition(.push(from: .bottom))
                    }
                }
            }
            .foregroundStyle(Color.ink)
            Spacer(minLength: 0)
        }
        .padding(16)
        .sticker(found ? .honey : .cream, RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// 뷰 좌표계 사각형들을 잉크 테두리 + 스티커 꼬리표로.
struct Boxes: View {
    let boxes: [CGRect]
    let label: String
    var body: some View {
        ForEach(Array(boxes.enumerated()), id: \.offset) { _, r in
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.ink, lineWidth: 5)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.honey.opacity(0.18)))
                Text("\(label) here!")
                    .font(.caption.weight(.heavy)).foregroundStyle(Color.ink)
                    .fixedSize()   // 박스가 좁아도 한 줄 유지
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .sticker()
                    .rotationEffect(.degrees(-5))
                    .offset(y: -20)
            }
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
        }
    }
}

/// 폭죽. trigger가 바뀔 때마다 화면 중앙에서 색종이 40개가 터져 떨어진다.
struct Confetti: View {
    let trigger: Int
    struct Piece: Identifiable {
        let id = UUID()
        let angle = Double.random(in: 0..<(2 * .pi))
        let dist = CGFloat.random(in: 120...320)
        let spin = Double.random(in: -720...720)
        let size = CGFloat.random(in: 8...16)
        let color: Color = [.honey, .cream, .bear, .blush, Color(red: 0.6, green: 0.8, blue: 0.9)].randomElement()!
        let round = Bool.random()
    }
    @State private var pieces: [Piece] = []
    @State private var fly = false

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                PieceView(p: p, fly: fly)
            }
        }
        .onChange(of: trigger) { _, _ in
            pieces = (0..<40).map { _ in Piece() }
            fly = false
            // 같은 패스에서 fly=true까지 바꾸면 시작 프레임 없이 끝 상태로 바로 그려져 아무것도 안 보인다. 한 틱 뒤에 애니메이션.
            DispatchQueue.main.async { withAnimation(.easeOut(duration: 2.0)) { fly = true } }
            Task { try? await Task.sleep(for: .seconds(2.1)); pieces = [] }
        }
    }
}

struct PieceView: View {
    let p: Confetti.Piece
    let fly: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: p.round ? p.size : 2)
        let dx: CGFloat = fly ? cos(p.angle) * p.dist : 0
        let dy: CGFloat = fly ? sin(p.angle) * p.dist + 160 : 0   // +160: 중력으로 아래로 처짐
        shape.fill(p.color)
            .overlay(shape.stroke(Color.ink, lineWidth: 2))
            .frame(width: p.size, height: p.size * (p.round ? 1 : 0.6))
            .rotationEffect(.degrees(fly ? p.spin : 0))
            .offset(x: dx, y: dy)
            .opacity(fly ? 0 : 1)
    }
}

/// 사진을 aspect-fit 으로 띄우고 Vision 정규화 박스를 그 위에 맞춰 그린다.
struct PhotoMode: View {
    let image: UIImage?
    let boxes: [CGRect]
    let label: String
    var body: some View {
        GeometryReader { g in
            if let image {
                let scale = min(g.size.width / image.size.width, g.size.height / image.size.height)
                let w = image.size.width * scale, h = image.size.height * scale
                let ox = (g.size.width - w) / 2, oy = (g.size.height - h) / 2
                Image(uiImage: image).resizable().frame(width: w, height: h).position(x: g.size.width/2, y: g.size.height/2)
                Boxes(boxes: boxes.map {
                    CGRect(x: ox + $0.minX * w, y: oy + (1 - $0.maxY) * h, width: $0.width * w, height: $0.height * h)
                }, label: label)
            } else {
                VStack(spacing: 12) {
                    Image("mascot_search").resizable().scaledToFit().frame(width: 180)
                    Text("No camera in the Simulator.\nPick a photo to test detection.")
                        .multilineTextAlignment(.center).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// 앱스토어 스크린샷용(디버그 빌드 전용): 시뮬레이터에서 `-demoPhoto <경로>`로 사진을 바로 띄우고 사진 버튼을 숨긴다.
enum Demo {
    /// `-demoAddName 여친`: '+' 화면 이름 칸을 미리 채운다(시뮬레이터 입력 도구가 한글을 못 쳐서).
    static let addName: String? = {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoAddName")
        #else
        return nil
        #endif
    }()
    /// `-demoHits "x,y,w,h,conf"`: 가르친 물건의 매칭 결과(Vision 정규화 좌표). 같은 Matcher를 Mac에서 돌린 값.
    static let hits: [Hit]? = {
        #if DEBUG
        guard let s = UserDefaults.standard.string(forKey: "demoHits") else { return nil }
        let v = s.split(separator: ",").compactMap { Double($0) }
        guard v.count == 5 else { return nil }
        return [Hit(box: CGRect(x: v[0], y: v[1], width: v[2], height: v[3]), conf: Float(v[4]))]
        #else
        return nil
        #endif
    }()
    static let photo: UIImage? = {
        #if DEBUG
        guard let path = UserDefaults.standard.string(forKey: "demoPhoto") else { return nil }
        return UIImage(contentsOfFile: path)
        #else
        return nil
        #endif
    }()
}
