#!/bin/zsh
# 사람(옷차림) 가르치기 검증용 가상 인물 이미지. 실행: zsh -ic ./Design/test/gen_person.sh
cd "$(dirname "$0")"
g() {
  jq -n --arg p "$3" --arg s "$2" '{model:"gpt-image-2.5-flare", prompt:$p, size:$s, n:1}' \
  | curl -sS https://api.openai.com/v1/images/generations -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" -d @- \
  | jq -r '.data[0].b64_json // empty' | base64 -d > "$1.png"
  [ -s "$1.png" ] && echo "ok $1" || echo "FAIL $1"
}
P="a young woman with a short black bob haircut wearing a bright yellow hoodie and light blue jeans"
g pteach1 1024x1536 "realistic smartphone photo, full body, of $P, standing in a hallway at home, facing the camera" &
g pteach2 1024x1536 "realistic smartphone photo, full body, of $P, standing in a kitchen, turned slightly sideways" &
g pscene 1536x1024 "realistic wide smartphone photo of a living room with two people: on the left a man in a dark green sweater sitting on the sofa reading, on the right $P standing near the window" &
g pscene_none 1536x1024 "realistic wide smartphone photo of a living room with two people: on the left a man in a dark green sweater sitting on the sofa reading, on the right a woman with long brown hair in a grey cardigan standing near the window" &
wait
