import SwiftUI
import Vision

/// 사용자가 추가한 물건 목록. 기기 안(Documents)에만 저장.
/// - extras: 이름으로 추가했는데 모델이 이미 아는 물건(곰인형, 노트북 …)
/// - custom: 사진으로 가르친 물건. 특징값은 custom-<id>.prints, 칩 썸네일은 custom-<id>.jpg
@Observable final class ItemStore {
    private(set) var extras: [Target] = []
    private(set) var custom: [CustomItem] = []

    var all: [Item] { Target.presets.map(Item.known) + extras.map(Item.known) + custom.map(Item.custom) }

    private struct Saved: Codable { var extras: [Target]; var custom: [CustomItem] }
    private static let file = URL.documentsDirectory.appending(path: "items.json")
    private static func url(_ c: CustomItem, _ ext: String) -> URL { URL.documentsDirectory.appending(path: "custom-\(c.id.uuidString).\(ext)") }

    init() {
        if let d = try? Data(contentsOf: Self.file), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            extras = s.extras; custom = s.custom
        }
    }
    private func persist() {
        try? JSONEncoder().encode(Saved(extras: extras, custom: custom)).write(to: Self.file, options: .atomic)
    }

    /// 이름이 아는 물건이면 그걸 돌려주고(프리셋이 아니면 칩에 추가), 모르면 nil.
    func known(_ name: String) -> Item? {
        guard let t = Target.match(name) else { return nil }
        if !Target.presets.contains(t), !extras.contains(t) { extras.append(t); persist() }
        return .known(t)
    }

    /// 사진으로 가르치기. 무거운 Vision 작업이라 백그라운드에서.
    func teach(name: String, photos: [UIImage], person: Bool = false) async -> Item? {
        let refs = await Task.detached(priority: .userInitiated) {
            photos.compactMap { img -> VNFeaturePrintObservation? in
                guard let cg = img.cgImage else { return nil }
                do { return try Matcher.reference(VNImageRequestHandler(cgImage: cg, orientation: .init(img.imageOrientation))) }
                catch { NSLog("TeddyFinder teach failed: \(error)"); return nil }
            }
        }.value
        guard !refs.isEmpty,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: refs as NSArray, requiringSecureCoding: true)
        else { return nil }
        let c = CustomItem(name: name.trimmingCharacters(in: .whitespacesAndNewlines), person: person ? true : nil)
        try? data.write(to: Self.url(c, "prints"), options: .atomic)
        let thumb = photos[0].preparingThumbnail(of: CGSize(width: 120, height: 120 * photos[0].size.height / photos[0].size.width))
        try? thumb?.jpegData(compressionQuality: 0.8)?.write(to: Self.url(c, "jpg"))
        custom.append(c); persist()
        return .custom(c)
    }

    func refs(_ c: CustomItem) -> [VNFeaturePrintObservation] {
        guard let d = try? Data(contentsOf: Self.url(c, "prints")) else { return [] }
        // unarchivedArrayOfObjects(ofClass:)는 특징값 안쪽 필드(timeRange)에서 실패한다. 클래스 목록으로 풀어야 됨.
        let obj = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, VNFeaturePrintObservation.self], from: d)
        return obj as? [VNFeaturePrintObservation] ?? []
    }
    func thumbnail(_ c: CustomItem) -> UIImage? { UIImage(contentsOfFile: Self.url(c, "jpg").path(percentEncoded: false)) }

    func remove(_ item: Item) {
        switch item {
        case .known(let t): extras.removeAll { $0 == t }
        case .custom(let c):
            custom.removeAll { $0 == c }
            for ext in ["prints", "jpg"] { try? FileManager.default.removeItem(at: Self.url(c, ext)) }
        }
        try? FileManager.default.removeItem(at: LastSeen.url(item))
        persist()
    }
}
