import Foundation
import CoreGraphics

/// 탐지 한 건. box 좌표계는 넘기는 쪽 마음(카메라: 화면 좌표, 사진: Vision 정규화).
struct Hit { var box: CGRect; var conf: Float }

/// 프레임마다 흔들리는 탐지 결과를 "찾음/못 찾음" + 안정된 박스 하나로 다듬는다.
/// - 처음 찾기는 깐깐하게(신뢰도 0.5, 연속 3프레임), 한 번 찾은 뒤엔 너그럽게(0.25) 유지한다.
/// - 놓침 판정은 프레임 수가 아니라 시간(2초). 폰마다 탐지 속도가 달라도 체감이 같다.
/// - 박스는 새 위치로 35%씩 따라가서 덜덜 떨지 않는다.
struct Tracker {
    var enterConf: Float = 0.5
    var stayConf: Float = 0.25
    var enterStreak = 3
    var grace: TimeInterval = 2
    var follow: CGFloat = 0.35

    private(set) var found = false
    private(set) var box: CGRect?
    private(set) var lastSeen = Date.distantPast
    private var streak = 0

    /// 이번 프레임에 새로 "찾음"이 됐으면 true (폭죽·장면 저장 트리거).
    mutating func update(_ hits: [Hit], now: Date = .now) -> Bool {
        let need = found ? stayConf : enterConf
        guard let best = hits.filter({ $0.conf >= need }).max(by: { $0.conf < $1.conf }) else {
            streak = 0
            if found, now.timeIntervalSince(lastSeen) > grace { found = false }
            if !found { box = nil }
            return false
        }
        streak += 1
        lastSeen = now
        box = (found ? box : nil).map { lerp($0, best.box) } ?? best.box
        if !found, streak >= enterStreak { found = true; return true }
        return false
    }

    /// 사진 한 장: 연속 프레임이 없으니 바로 판정.
    mutating func single(_ hits: [Hit]) -> Bool {
        let (e, s) = (enterConf, stayConf)   // 민감도 설정은 유지
        self = Tracker(enterStreak: 1)
        (enterConf, stayConf) = (e, s)
        return update(hits)
    }

    /// 찾은 상태지만 방금(0.3초) 못 봤는지. 박스를 흐리게 그릴 때 쓴다.
    func stale(now: Date = .now) -> Bool { found && now.timeIntervalSince(lastSeen) > 0.3 }

    private func lerp(_ a: CGRect, _ b: CGRect) -> CGRect {
        let t = follow
        return CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
                      width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }
}
