import Vision
import CoreML
import UIKit

/// 탐지기. 결과는 Vision 정규화 좌표(원점 좌하단).
/// - 아는 물건: YOLOv8n(COCO)에서 그 클래스만.
/// - 가르친 물건: YOLO가 본 아무 물체 + 눈에 띄는 물체를 후보로, 등록 사진과 특징값 비교(Matcher).
final class Detector {
    /// 찾을 물건과(가르친 물건이면) 등록 특징값. 메인에서 바꾸고 백그라운드에서 읽으니 한 번에 통째로 교체.
    var item: (Item, [VNFeaturePrintObservation]) = (.known(.remote), [])
    private let request: VNCoreMLRequest
    private var busy = false

    init() {
        let url = Bundle.main.url(forResource: "yolov8n", withExtension: "mlmodelc")!
        let model = try! VNCoreMLModel(for: MLModel(contentsOf: url))
        request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
    }

    /// 이전 프레임 처리 중이면 그냥 버린다(실시간 우선).
    func detect(_ buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, done: @escaping ([Hit]) -> Void) {
        guard !busy else { return }
        busy = true
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation)
        run(handler, done: done)
    }

    func detect(_ image: UIImage, done: @escaping ([Hit]) -> Void) {
        guard let cg = image.cgImage else { return done([]) }
        run(VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation)), done: done)
    }

    private func run(_ handler: VNImageRequestHandler, done: @escaping ([Hit]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let (item, refs) = self.item
            try? handler.perform([self.request])
            let obs = self.request.results as? [VNRecognizedObjectObservation] ?? []
            // 약한 탐지도 넘긴다. 찾음/유지 기준(0.5/0.25)은 Tracker가 판단.
            let hits: [Hit]
            switch item {
            case .known(let t):
                hits = obs.filter { $0.labels.first?.identifier == t.rawValue && $0.confidence >= 0.2 }
                    .sorted { $0.confidence > $1.confidence }
                    .map { Hit(box: $0.boundingBox, conf: $0.confidence) }
            case .custom(let c):
                let cands = c.person == true ? Matcher.people(obs)
                    : (try? Matcher.candidates(handler, extra: obs.map(\.boundingBox))) ?? []
                do { hits = try Matcher.match(handler, candidates: cands, refs: refs, person: c.person == true) }
                catch { NSLog("TeddyFinder match error: \(error)"); hits = [] }
            }
            self.busy = false
            DispatchQueue.main.async { done(hits) }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up;          case .down: self = .down
        case .left: self = .left;      case .right: self = .right
        case .upMirrored: self = .upMirrored; case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored; case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
