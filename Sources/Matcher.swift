import Vision
import CoreML
import CoreGraphics

/// "사진으로 가르친 물건" 찾기. 전부 아이폰 기본 Vision 기능만 쓴다(새 모델 없음).
/// 1) 등록: 사진마다 가장 눈에 띄는 물체를 잘라 특징값(feature print)을 만든다.
/// 2) 탐색: 프레임에서 후보 위치(눈에 띄는 물체 + YOLO가 본 아무 물체)를 뽑아 특징값끼리 거리를 잰다.
/// 거리 → 신뢰도 변환 기준은 Checks/matcher 로 맞춘 값.
enum Matcher {
    /// 등록 사진 한 장 → 특징값.
    static func reference(_ h: VNImageRequestHandler) throws -> VNFeaturePrintObservation? {
        let sal = sim(VNGenerateObjectnessBasedSaliencyImageRequest())
        try h.perform([sal])
        let box = sal.results?.first?.salientObjects?.max { $0.confidence < $1.confidence }?.boundingBox
        return try prints(h, [box.map { pad($0, 0.1) } ?? CGRect(x: 0, y: 0, width: 1, height: 1)]).first ?? nil
    }

    /// 한 프레임의 후보 위치들. extra = YOLO가 본 박스들(클래스는 무시). 겹치는 건 하나만, 최대 limit개.
    static func candidates(_ h: VNImageRequestHandler, extra: [CGRect], limit: Int = 8) throws -> [CGRect] {
        let sal = sim(VNGenerateObjectnessBasedSaliencyImageRequest())
        try h.perform([sal])
        let salient = sal.results?.first?.salientObjects?.map(\.boundingBox) ?? []
        var out: [CGRect] = []
        for r in extra + salient where r.width * r.height > 0.0005 && r.width * r.height < 0.6 {
            if !out.contains(where: { iou($0, r) > 0.6 }) { out.append(r) }
            if out.count == limit { break }
        }
        return out
    }

    /// 사람을 가르친 경우의 후보: YOLO가 "사람"이라고 본 박스만.
    static func people(_ obs: [VNRecognizedObjectObservation]) -> [CGRect] {
        obs.filter { $0.labels.first?.identifier == "person" && $0.confidence >= 0.3 }.map(\.boundingBox)
    }

    /// 후보마다 등록 사진과 가장 가까운 거리 → Hit(신뢰도).
    static func match(_ h: VNImageRequestHandler, candidates: [CGRect], refs: [VNFeaturePrintObservation], person: Bool = false) throws -> [Hit] {
        guard !refs.isEmpty else { return [] }
        let scored = try zip(candidates, prints(h, candidates.map { pad($0, 0.1) })).compactMap { box, fp -> (CGRect, Float)? in
            guard let fp else { return nil }
            let d = refs.compactMap { r -> Float? in var x: Float = 0; try? fp.computeDistance(&x, to: r); return x }.min() ?? .infinity
            return (box, d)
        }
        // 후보가 전부 똑같이 가까우면 특징값이 고장난 것(시뮬레이터 CPU 경로에서 실제로 0 근처로 나옴). 아무거나 찍지 말고 못 찾음 처리.
        let ds = scored.map(\.1)
        if ds.count >= 3, let lo = ds.min(), let hi = ds.max(), hi - lo < 0.02 { return [] }
        return scored.map { Hit(box: $0.0, conf: person ? personConf(distance: $0.1) : conf(distance: $0.1)) }.sorted { $0.conf > $1.conf }
    }

    /// 거리(작을수록 비슷) → 0~1 신뢰도. near 이하면 1, far 이상이면 0.
    /// 측정(Checks/matcher): 같은 물건 0.64, 다른 물건 0.94~1.1. → Tracker 기준 0.5(찾음)=거리 0.775, 0.25(유지)=0.86.
    /// ponytail: 생성 이미지로 맞춘 값. 실사용에서 놓치면 far를 올리고, 엉뚱한 걸 잡으면 내린다.
    static var near: Float = 0.6, far: Float = 0.95
    static func conf(distance d: Float) -> Float { max(0, min(1, (far - d) / (far - near))) }

    /// 사람끼리는 자세·배경이 비슷해서 다른 사람도 꽤 가깝게 나온다. 더 깐깐한 구간을 쓴다.
    /// 측정: 같은 사람(같은 옷) 0.45~0.47, 비슷하게 서 있는 다른 사람 0.67~0.69, 앉아 있는 남자 1.0.
    /// → 찾음(0.5) = 거리 0.585, 유지(0.25) = 0.65. 다른 사람은 유지 기준도 못 넘는다.
    static var personNear: Float = 0.45, personFar: Float = 0.72
    static func personConf(distance d: Float) -> Float { max(0, min(1, (personFar - d) / (personFar - personNear))) }

    // MARK: -

    private static func prints(_ h: VNImageRequestHandler, _ rois: [CGRect]) throws -> [VNFeaturePrintObservation?] {
        let reqs = rois.map { roi -> VNGenerateImageFeaturePrintRequest in
            let r = sim(VNGenerateImageFeaturePrintRequest())
            r.imageCropAndScaleOption = .scaleFit
            r.regionOfInterest = roi
            return r
        }
        try h.perform(reqs)
        return reqs.map { $0.results?.first }
    }
    /// 시뮬레이터는 Vision 내장 모델을 GPU/ANE로 못 돌려서("Failed to create espresso context") CPU로 돌린다. 실기기는 그대로.
    #if targetEnvironment(simulator)
    static var forceCPU = true
    #else
    static var forceCPU = false
    #endif
    private static func sim<R: VNRequest>(_ r: R) -> R {
        if forceCPU, let cpu = MLComputeDevice.allComputeDevices.first(where: { if case .cpu = $0 { true } else { false } }) {
            for stage in ((try? r.supportedComputeStageDevices)?.keys).map(Array.init) ?? [] { r.setComputeDevice(cpu, for: stage) }
        }
        return r
    }

    static func pad(_ r: CGRect, _ f: CGFloat) -> CGRect {
        r.insetBy(dx: -r.width * f, dy: -r.height * f).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b); guard !i.isNull else { return 0 }
        let ia = i.width * i.height
        return ia / (a.width * a.height + b.width * b.height - ia)
    }
}
