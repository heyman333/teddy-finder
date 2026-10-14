import Foundation

/// 모델(YOLOv8n, COCO)이 이미 아는 물건. rawValue = COCO 클래스명.
/// presets는 처음부터 칩으로 보이고, 나머지는 사용자가 이름을 입력하면 연결된다.
enum Target: String, CaseIterable, Identifiable, Codable {
    case person
    case remote, cellPhone = "cell phone", mouse, scissors, toothbrush, cup, bottle, book
    case keyboard, laptop, handbag, backpack, umbrella, teddyBear = "teddy bear", clock, spoon, bowl, tv, vase, hairDrier = "hair drier"

    static let presets: [Target] = [.remote, .person, .cellPhone, .mouse, .scissors, .toothbrush, .cup, .bottle, .book]
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .person: "💕"
        case .remote: "📺"; case .cellPhone: "📱"; case .mouse: "🖱️"; case .scissors: "✂️"
        case .toothbrush: "🪥"; case .cup: "☕️"; case .bottle: "🍼"; case .book: "📚"
        case .keyboard: "⌨️"; case .laptop: "💻"; case .handbag: "👜"; case .backpack: "🎒"
        case .umbrella: "☂️"; case .teddyBear: "🧸"; case .clock: "⏰"; case .spoon: "🥄"
        case .bowl: "🥣"; case .tv: "🖥️"; case .vase: "🏺"; case .hairDrier: "💨"
        }
    }
    var label: String {
        switch self {
        case .person: String(localized: "Person")
        case .remote: String(localized: "Remote");         case .cellPhone: String(localized: "Phone")
        case .mouse: String(localized: "Mouse");           case .scissors: String(localized: "Scissors")
        case .toothbrush: String(localized: "Toothbrush"); case .cup: String(localized: "Cup")
        case .bottle: String(localized: "Bottle");         case .book: String(localized: "Book")
        case .keyboard: String(localized: "Keyboard");     case .laptop: String(localized: "Laptop")
        case .handbag: String(localized: "Handbag");       case .backpack: String(localized: "Backpack")
        case .umbrella: String(localized: "Umbrella");     case .teddyBear: String(localized: "Teddy bear")
        case .clock: String(localized: "Clock");           case .spoon: String(localized: "Spoon")
        case .bowl: String(localized: "Bowl");             case .tv: String(localized: "TV")
        case .vase: String(localized: "Vase");             case .hairDrier: String(localized: "Hair dryer")
        }
    }
    /// 사용자가 입력할 법한 이름들(영/한). 비교는 소문자·공백 제거 후.
    var synonyms: [String] {
        switch self {
        // 사람은 "아무나 한 명"을 찾는다. 특정인을 알아보는 얼굴 인식은 일부러 안 한다(동의 없는 추적 위험).
        case .person: ["person", "someone", "people", "human", "girlfriend", "boyfriend", "partner", "wife", "husband",
                       "mom", "dad", "friend", "kid", "baby",
                       "사람", "여자친구", "여친", "남자친구", "남친", "애인", "연인", "아내", "남편", "와이프",
                       "엄마", "아빠", "친구", "아기", "동생", "언니", "오빠", "누나", "형"]
        case .remote: ["remote", "remotecontrol", "tvremote", "리모컨", "리모콘", "티비리모컨", "tv리모컨"]
        case .cellPhone: ["phone", "cellphone", "smartphone", "iphone", "mobile", "핸드폰", "휴대폰", "휴대전화", "스마트폰", "아이폰", "폰"]
        case .mouse: ["mouse", "마우스"]
        case .scissors: ["scissors", "가위"]
        case .toothbrush: ["toothbrush", "칫솔"]
        case .cup: ["cup", "mug", "컵", "머그", "머그컵", "잔"]
        case .bottle: ["bottle", "waterbottle", "병", "물병", "생수병"]
        case .book: ["book", "notebook", "책", "공책"]
        case .keyboard: ["keyboard", "키보드"]
        case .laptop: ["laptop", "macbook", "notebookcomputer", "노트북", "랩탑", "맥북"]
        case .handbag: ["handbag", "purse", "bag", "가방", "핸드백"]
        case .backpack: ["backpack", "백팩", "책가방", "배낭"]
        case .umbrella: ["umbrella", "우산"]
        case .teddyBear: ["teddybear", "teddy", "plushie", "곰인형", "인형", "테디베어"]
        case .clock: ["clock", "시계", "탁상시계"]
        case .spoon: ["spoon", "숟가락", "스푼"]
        case .bowl: ["bowl", "그릇", "볼"]
        case .tv: ["tv", "television", "티비", "텔레비전"]
        case .vase: ["vase", "꽃병"]
        case .hairDrier: ["hairdryer", "hairdrier", "dryer", "드라이기", "헤어드라이기", "드라이어"]
        }
    }

    /// 입력한 이름 → 이미 아는 물건. 정확히 같은 이름 우선, 없으면 문장 속 가장 긴 이름("우리집 tv 리모컨" → 리모컨).
    /// 못 맞추면 nil → "사진으로 가르치기"로.
    static func match(_ text: String) -> Target? {
        let q = text.lowercased().filter { !$0.isWhitespace }
        guard !q.isEmpty else { return nil }
        if let exact = allCases.first(where: { $0.synonyms.contains(q) }) { return exact }
        // 한 글자 이름("폰", "잔", "볼")은 다른 단어 속에 너무 흔해서 포함 검사에서 뺀다.
        let found = allCases.flatMap { t in t.synonyms.filter { $0.count >= 2 && q.contains($0) }.map { (t, $0.count) } }
        return found.max { $0.1 < $1.1 }?.0
    }
}

/// 사용자가 사진으로 가르친 물건. 특징값 파일은 CustomItems가 관리.
struct CustomItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// 사람을 가르친 경우(여자친구·남자친구 등). 그날 옷차림으로 알아보고, 화면 속 "사람"끼리만 비교한다.
    /// 예전 저장 파일엔 이 키가 없어서 옵셔널.
    var person: Bool?
}

/// 찾을 수 있는 것 전부: 모델이 아는 물건 또는 사진으로 가르친 물건.
enum Item: Hashable, Identifiable, Codable {
    case known(Target)
    case custom(CustomItem)

    var id: String {
        switch self { case .known(let t): t.rawValue; case .custom(let c): "custom-\(c.id.uuidString)" }
    }
    var label: String {
        switch self { case .known(let t): t.label; case .custom(let c): c.name }
    }
    var emoji: String {
        switch self { case .known(let t): t.emoji; case .custom(let c): c.person == true ? "💕" : "🐾" }
    }
}
