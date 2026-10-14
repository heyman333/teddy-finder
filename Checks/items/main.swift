// 입력한 이름 → 아는 물건 연결 확인. 실행: swiftc Sources/Items.swift Checks/items/main.swift -o /tmp/ic && /tmp/ic
import Foundation

let cases: [(String, Target?)] = [
    ("리모컨", .remote), ("리모콘", .remote), ("TV Remote", .remote), ("우리집 티비 리모컨", .remote),
    ("핸드폰", .cellPhone), ("아이폰", .cellPhone), ("폰", .cellPhone), ("iPhone", .cellPhone),
    ("머그컵", .cup), ("곰인형", .teddyBear), ("Teddy Bear", .teddyBear), ("노트북", .laptop), ("맥북 프로", .laptop),
    ("드라이기", .hairDrier), ("우산", .umbrella), ("백팩", .backpack), ("가방", .handbag),
    ("여자친구", .person), ("남친", .person), ("우리 엄마", .person), ("Boyfriend", .person), ("사람", .person),
    // 모르는 물건 → nil (사진으로 가르치기)
    ("에어팟", nil), ("AirPods", nil), ("차 키", nil), ("지갑", nil), ("안경", nil), ("", nil), ("   ", nil),
    // 한 글자 이름은 다른 단어 속에서 잡지 않는다: "이어폰"에 "폰"이 있어도 휴대폰 아님
    ("이어폰", nil), ("헤드폰", nil),
]
var bad = 0
for (q, want) in cases where Target.match(q) != want {
    print("FAIL \"\(q)\" → \(String(describing: Target.match(q))), want \(String(describing: want))"); bad += 1
}
precondition(bad == 0)
print("items ok (\(cases.count))")
