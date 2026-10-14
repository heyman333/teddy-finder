// Matcher 보정·확인 (Mac에서 실행). 실행:
// swiftc -O Sources/Tracker.swift Sources/Matcher.swift Checks/matcher/main.swift -o /tmp/mc && /tmp/mc
// 등록 사진(teach1~3)으로 scene(에어팟 있음)/scene_none(없음)에서 후보별 거리를 출력하고 잘라낸 후보를 /tmp/mc_out 에 저장.
import Foundation
import Vision
import CoreML
import ImageIO
import UniformTypeIdentifiers

setvbuf(stdout, nil, _IONBF, 0)   // 실패해도 출력이 남게
let dir = "Design/test/"
Matcher.forceCPU = CommandLine.arguments.contains("--cpu")
print("cpu:", Matcher.forceCPU)
func cg(_ name: String) -> CGImage {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: dir + name + ".png") as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}
let yolo = try VNCoreMLModel(for: MLModel(contentsOf: MLModel.compileModel(at: URL(fileURLWithPath: "Sources/yolov8n.mlpackage"))))

let refs = try ["teach1", "teach2", "teach3"].compactMap { try Matcher.reference(VNImageRequestHandler(cgImage: cg($0))) }
print("refs:", refs.count)
let (near, far) = (Matcher.near, Matcher.far)
Matcher.near = 0; Matcher.far = 10   // conf → 거리 역산용: d = 10 - 10*conf
var best: [String: Float] = [:]

let out = URL(fileURLWithPath: "/tmp/mc_out"); try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

for scene in ["scene", "scene_none"] {
    let img = cg(scene)
    let h = VNImageRequestHandler(cgImage: img)
    let y = VNCoreMLRequest(model: yolo); y.imageCropAndScaleOption = .scaleFill
    try h.perform([y])
    let yobs = (y.results as? [VNRecognizedObjectObservation]) ?? []
    let t0 = Date()
    let cands = try Matcher.candidates(h, extra: yobs.map(\.boundingBox))
    let hits = try Matcher.match(h, candidates: cands, refs: refs)
    print("\n== \(scene): \(cands.count) candidates, \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
    best[scene] = hits.first.map { 10 - 10 * $0.conf }
    for (i, hit) in hits.enumerated() {
        let d = 10 - 10 * hit.conf
        let label = yobs.first { Matcher.iou($0.boundingBox, hit.box) > 0.6 }?.labels.first?.identifier ?? "-"
        let b = hit.box
        print(String(format: "  #%d d=%.3f  yolo=%@  box=(%.2f,%.2f,%.2f,%.2f)", i, d, label, b.minX, b.minY, b.width, b.height))
        let W = CGFloat(img.width), H = CGFloat(img.height)
        if let crop = img.cropping(to: CGRect(x: b.minX * W, y: (1 - b.maxY) * H, width: b.width * W, height: b.height * H)),
           let dst = CGImageDestinationCreateWithURL(out.appending(path: "\(scene)_\(i)_d\(String(format: "%.2f", d)).png") as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dst, crop, nil); CGImageDestinationFinalize(dst)
        }
    }
}

// 앱에서 쓰는 기준으로 판정: 에어팟 장면은 "찾음"(신뢰도 ≥ 0.5), 없는 장면은 "유지"(≥ 0.25)도 안 돼야 한다.
Matcher.near = near; Matcher.far = far
let found = Matcher.conf(distance: best["scene"]!), ghost = Matcher.conf(distance: best["scene_none"]!)
print(String(format: "\nscene conf=%.2f (need ≥ 0.5), scene_none conf=%.2f (need < 0.25)", found, ghost))
precondition(found >= 0.5 && ghost < 0.25, "matcher thresholds")
print("matcher ok")

// ── 사람(옷차림) 가르치기: 노란 후디 여성을 가르치고, 두 사람 있는 거실에서 그 사람만 골라야 한다.
func people(_ name: String) throws -> (VNImageRequestHandler, [CGRect]) {
    let h = VNImageRequestHandler(cgImage: cg(name))
    let y = VNCoreMLRequest(model: yolo); y.imageCropAndScaleOption = .scaleFill
    try h.perform([y])
    return (h, Matcher.people((y.results as? [VNRecognizedObjectObservation]) ?? []))
}
let prefs = try ["pteach1", "pteach2"].compactMap { try Matcher.reference(VNImageRequestHandler(cgImage: cg($0))) }
let (ph, pc) = try people("pscene")
let ps = try Matcher.match(ph, candidates: pc, refs: prefs, person: true)
let (nh, nc) = try people("pscene_none")
let ns = try Matcher.match(nh, candidates: nc, refs: prefs, person: true)
for (n, hs) in [("pscene", ps), ("pscene_none", ns)] {
    print("\n== \(n): " + hs.map { String(format: "conf=%.2f x=%.2f", $0.conf, $0.box.midX) }.joined(separator: " | "))
}
// 노란 후디 여성은 오른쪽(x>0.5). 그 사람이 1등이고 "찾음" 기준을 넘어야 하며, 다른 사람만 있는 장면에선 넘으면 안 된다.
precondition(pc.count >= 2 && ps.first!.box.midX > 0.5 && ps.first!.conf >= 0.5, "person: wrong pick")
precondition((ns.first?.conf ?? 0) < 0.25, "person: false match")   // 유지 기준도 못 넘어야 함
print("person ok")
