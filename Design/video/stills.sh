#!/bin/zsh
# 숏폼용 가상 인물 스틸 이미지. 실행: zsh -ic ./Design/video/stills.sh
cd "$(dirname "$0")"
g() {
  jq -n --arg p "$3" --arg s "$2" '{model:"gpt-image-2.5-flare", prompt:$p, size:$s, n:1}' \
  | curl -sS https://api.openai.com/v1/images/generations -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" -d @- \
  | jq -r '.data[0].b64_json // empty' | base64 -d > "$1.png"
  [ -s "$1.png" ] && echo "ok $1" || echo "FAIL $1"
}
M="a young Korean man in his twenties with short black hair, wearing a navy cardigan over a white t-shirt"
W="a young woman with a short black bob haircut wearing a bright yellow hoodie and light blue jeans"
g hook 1024x1536 "realistic candid smartphone photo, vertical. At a crowded outdoor weekend flea market in Seoul, $M holds two iced coffees, standing on tiptoe and looking around the crowd, lost and a little panicked, funny expression. Natural daylight." &
g crowd 1024x1536 "realistic smartphone photo, vertical, taken at eye level at a crowded outdoor weekend flea market in Seoul, about ten fictional people browsing stalls at different distances, nobody else wears yellow; in the middle distance on the right, $W stands at a vintage clothing stall, full body visible. Natural daylight." &
g reunion 1024x1536 "realistic candid smartphone photo, vertical. At a crowded outdoor weekend flea market in Seoul, $M hands an iced coffee to $W, both laughing, she gives a thumbs up to the camera. Natural daylight, warm and funny mood." &
g pteach3 1024x1536 "realistic smartphone photo, full body, of $W, standing outside a cafe on a sunny street, smiling, slightly turned to the left" &
wait
