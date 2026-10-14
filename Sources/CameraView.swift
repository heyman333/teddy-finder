import SwiftUI
import AVFoundation
import Vision

/// 후면 카메라 프리뷰 + 프레임마다 탐지. boxes는 뷰 좌표계로 변환해 넘긴다.
struct CameraView: UIViewRepresentable {
    var item: (Item, [VNFeaturePrintObservation])
    /// 매 프레임 호출 (빈 결과 포함). 연속 판정은 호출하는 쪽에서.
    /// 두 번째 인자: 지금 프레임을 박스 그려진 사진으로 만들어 주는 함수. 필요할 때만 불러서 변환 비용을 아낀다.
    var onResult: ([Hit], @escaping () -> UIImage?) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        context.coordinator.start(on: v)
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.detector.item = item
        context.coordinator.onResult = onResult
    }
    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var onResult: ([Hit], @escaping () -> UIImage?) -> Void
        let session = AVCaptureSession()
        let detector = Detector()
        weak var view: PreviewView?

        init(onResult: @escaping ([Hit], @escaping () -> UIImage?) -> Void) { self.onResult = onResult }

        func start(on view: PreviewView) {
            self.view = view
            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera"))
            session.beginConfiguration()
            session.sessionPreset = .hd1280x720
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
            DispatchQueue.global().async { self.session.startRunning() }
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            // 세로 고정 앱: 센서 버퍼는 가로이므로 .right 로 돌려서 Vision에 넘긴다.
            detector.detect(pb, orientation: .right) { [weak self] visionHits in
                guard let layer = self?.view?.previewLayer else { return }
                let snapshot = { visionHits.first.flatMap { h in LastSeen.image(pb).map { LastSeen.stamp($0, box: h.box) } } }
                self?.onResult(visionHits.map { h in
                    let v = h.box
                    // Vision 박스는 세로로 세운 이미지 기준(좌하단 원점). metadata rect는 센서 원본(가로, 좌상단 원점) 기준이라
                    // 축을 바꿔줘야 한다: 세운 좌표 (u,v) -> 원본 (v, 1-u). 안 하면 박스가 90도 돌아가 엉뚱한 데 찍힌다.
                    let r = layer.layerRectConverted(fromMetadataOutputRect:
                        CGRect(x: 1 - v.maxY, y: 1 - v.maxX, width: v.height, height: v.width))
                    return Hit(box: r, conf: h.conf)
                }, snapshot)
            }
        }
    }
}
