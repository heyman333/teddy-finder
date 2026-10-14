#!/bin/zsh
# "사진으로 가르치기" 검증용 이미지. 실행: zsh -ic ./Design/test/gen_custom.sh
cd "$(dirname "$0")"
g() { # name size prompt
  jq -n --arg p "$3" --arg s "$2" '{model:"gpt-image-2.5-flare", prompt:$p, size:$s, n:1}' \
  | curl -sS https://api.openai.com/v1/images/generations -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" -d @- \
  | jq -r '.data[0].b64_json // empty' | base64 -d > "$1.png"
  [ -s "$1.png" ] && echo "ok $1" || echo "FAIL $1"
}
g teach1 1024x1024 "realistic close-up smartphone photo of a white AirPods Pro charging case held in a hand, lid closed, plain wall background" &
g teach2 1024x1024 "realistic close-up smartphone photo of a white AirPods Pro charging case lying on a grey bed sheet, lid closed, top-down view" &
g teach3 1024x1024 "realistic close-up smartphone photo of a white AirPods Pro charging case on a wooden desk, lid closed, slight angle" &
g scene 1024x1536 "realistic casual smartphone photo looking down at a living room coffee table: a small white AirPods Pro charging case, a TV remote, a coffee mug, a few magazines and a set of keys, natural daylight, portrait orientation" &
g scene_none 1024x1536 "realistic casual smartphone photo looking down at a living room coffee table: a TV remote, a coffee mug, a few magazines and a set of keys, no earbuds, natural daylight, portrait orientation" &
wait
