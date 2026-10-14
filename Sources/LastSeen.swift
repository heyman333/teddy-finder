import SwiftUI
import CoreImage

/// 물건별 "마지막으로 찾은 장면" 사진. 기기 안(Documents)에만 저장, 날짜는 파일 수정 시각.
/// ponytail: 물건당 한 장만 덮어씀. 여러 장 기록(히스토리)이 필요하면 파일명에 날짜를 붙이면 된다.
enum LastSeen {
    static func url(_ t: Item) -> URL {
        URL.documentsDirectory.appending(path: "lastseen-\(t.id).jpg")
    }
    static func removeAll() {
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(at: URL.documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        where f.lastPathComponent.hasPrefix("lastseen-") { try? fm.removeItem(at: f) }
    }
    static func save(_ t: Item, _ image: UIImage) {
        try? image.jpegData(compressionQuality: 0.8)?.write(to: url(t), options: .atomic)
    }
    static func load(_ t: Item) -> (image: UIImage, date: Date)? {
        let u = url(t)
        guard let img = UIImage(contentsOfFile: u.path(percentEncoded: false)),
              let date = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return nil }
        return (img, date)
    }

    /// 사진에 찾은 위치 박스를 그려 넣은 사본(긴 변 1024px). box = Vision 정규화 좌표(원점 좌하단).
    static func stamp(_ image: UIImage, box: CGRect) -> UIImage {
        let s = min(1, 1024 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let r = CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height,
                           width: box.width * size.width, height: box.height * size.height).insetBy(dx: -6, dy: -6)
            let path = UIBezierPath(roundedRect: r, cornerRadius: 14)
            UIColor(Color.cream).setStroke(); path.lineWidth = 10; path.stroke()
            UIColor(Color.ink).setStroke(); path.lineWidth = 5; path.stroke()
        }
    }

    /// 카메라 버퍼 → 세로로 세운 UIImage.
    static let ci = CIContext()
    static func image(_ pb: CVPixelBuffer) -> UIImage? {
        let img = CIImage(cvPixelBuffer: pb).oriented(.right)
        return ci.createCGImage(img, from: img.extent).map { UIImage(cgImage: $0) }
    }
}

/// "못 찾겠어요" 시트: 지난번에 찾았던 장면을 보여준다.
struct LastSeenSheet: View {
    let target: Item
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            if let last = LastSeen.load(target) {
                Text("Last time it was here!")
                    .font(.system(.title, design: .rounded).weight(.black))
                Image(uiImage: last.image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(6).sticker(.cream, RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .rotationEffect(.degrees(-1.5))
                    .frame(maxHeight: 420)
                HStack(spacing: 10) {
                    Image("mascot_search").resizable().scaledToFit().frame(width: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Found \(last.date, format: .relative(presentation: .named))")
                            .font(.headline.weight(.heavy))
                        Text("Things often end up in the same spot. Try there first!")
                            .font(.subheadline.weight(.semibold)).opacity(0.75)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).sticker(.cream, RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Spacer()
                Image("mascot_search").resizable().scaledToFit().frame(width: 180)
                Text("I haven't found it yet")
                    .font(.system(.title2, design: .rounded).weight(.black))
                Text("Once I find it, I'll remember where it was.")
                    .font(.subheadline.weight(.semibold)).opacity(0.75).multilineTextAlignment(.center)
                Spacer()
            }
            Button { dismiss() } label: {
                Text("Keep looking").font(.headline.weight(.heavy)).foregroundStyle(Color.cream)
                    .padding(.horizontal, 22).padding(.vertical, 12)
            }
            .buttonStyle(.plain).sticker(.bear)
        }
        .foregroundStyle(Color.ink)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .presentationDetents([.large])
    }
}
