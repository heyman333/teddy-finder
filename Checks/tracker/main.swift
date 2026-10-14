// Tracker 동작 확인. 실행: swiftc Sources/Tracker.swift Checks/tracker/main.swift -o /tmp/tc && /tmp/tc
import Foundation
import CoreGraphics

let r = CGRect(x: 100, y: 100, width: 50, height: 80)
let t0 = Date(timeIntervalSince1970: 0)
func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

var t = Tracker()
// 약한 탐지(0.4)로는 못 찾는다
for i in 0..<10 { assert(!t.update([Hit(box: r, conf: 0.4)], now: at(Double(i) * 0.05))) }
assert(!t.found)
// 0.6 연속 3번 → 찾음, 정확히 한 번만 true
assert(!t.update([Hit(box: r, conf: 0.6)], now: at(1.0)))
assert(!t.update([Hit(box: r, conf: 0.6)], now: at(1.05)))
assert(t.update([Hit(box: r, conf: 0.6)], now: at(1.1)))
assert(t.found)
assert(!t.update([Hit(box: r, conf: 0.6)], now: at(1.15)))   // 이미 찾은 상태에선 다시 트리거 안 함
// 찾은 뒤엔 0.3짜리 흔들리는 탐지도 유지
assert(!t.update([Hit(box: r, conf: 0.3)], now: at(1.2))); assert(t.found)
// 빈 프레임이 1.9초 이어져도 유지, 박스도 그대로
for i in 1...38 { _ = t.update([], now: at(1.2 + Double(i) * 0.05)) }
assert(t.found && t.box != nil && t.stale(now: at(3.1)))
// 2초 넘게 못 보면 놓침
_ = t.update([], now: at(3.3))
assert(!t.found && t.box == nil)
// 다시 찾을 땐 다시 깐깐하게(0.3으론 안 됨)
for i in 0..<5 { _ = t.update([Hit(box: r, conf: 0.3)], now: at(4 + Double(i) * 0.05)) }
assert(!t.found)
// 박스는 새 위치로 부드럽게 따라감
var s = Tracker(enterStreak: 1)
_ = s.update([Hit(box: r, conf: 0.9)], now: at(0))
_ = s.update([Hit(box: r.offsetBy(dx: 100, dy: 0), conf: 0.9)], now: at(0.05))
assert(abs(s.box!.minX - 135) < 0.001)
// 사진 한 장은 바로 판정
var p = Tracker()
assert(p.single([Hit(box: r, conf: 0.7)]) && p.found)
assert(!p.single([]) && !p.found)
print("tracker ok")
