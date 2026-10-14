#!/bin/zsh
# 이미지 에셋 생성. OPENAI_API_KEY는 ~/.zshrc에서. 재생성: zsh -ic ./Design/gen.sh
set -e
cd "$(dirname "$0")"
MODEL=${MODEL:-gpt-image-2.5-flare}
STYLE="hand-drawn cartoon sticker, thick wobbly black ink outlines, flat warm palette of honey yellow, soft peach, warm brown and cream, slightly rough playful 90s cartoon linework, chunky cream-white sticker border around the character, no text, no letters"
gen() { # name prompt background
  [ -n "$ONLY" ] && [ "$ONLY" != "$1" ] && return   # ONLY=icon 이면 아이콘만
  local bg=${3:-opaque}
  jq -n --arg m "$MODEL" --arg p "$2" --arg bg "$bg" \
    '{model:$m, prompt:$p, size:"1024x1024", quality:"high", output_format:"png", background:$bg, n:1}' \
  | curl -sS https://api.openai.com/v1/images/generations -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" -d @- > "$1.json"
  jq -r '.data[0].b64_json // empty' "$1.json" | base64 -d > "$1.png" 2>/dev/null
  [ -s "$1.png" ] && echo "ok $1" || { echo "FAIL $1"; jq -c '.error' "$1.json"; }
}
gen icon "minimal iOS app icon: only the face of a chubby round brown teddy bear, front view, simple dot eyes, rosy cheeks, tiny smile, holding one small round magnifying glass over one eye, very simple flat shapes, very few details, thick black outline, centered and large, full-bleed flat solid warm peach background (#FCE3CC) filling the whole square, no hole, no ground, no sticker border, no text" &
gen mascot_search "an extremely chubby, round, plump baby bear with a big round head, tiny ears, big sparkly eyes, rosy cheeks, short stubby arms, super cute kawaii proportions, peeking out of a round dark hole in the ground, holding black binoculars up to its eyes, searching curiously, visible from the belly up, centered, isolated on transparent background, $STYLE" transparent &
gen mascot_found "an extremely chubby, round, plump baby bear with a big round head, tiny ears, big sparkly eyes, rosy cheeks, short stubby arms, super cute kawaii proportions, jumping out of a round hole with both stubby arms raised high in joy, empty paws, holding nothing, huge happy open-mouth grin, eyes squeezed shut with joy, little stars and sparkles around it, full body, centered, isolated on transparent background, $STYLE" transparent &
gen splash_bear "sticker of only the face of a chubby round brown teddy bear, front view, simple dot eyes, rosy cheeks, happy smile, holding one small round magnifying glass over one eye, very simple flat shapes, very few details, thick black outline, centered, isolated on transparent background, no text" transparent &
wait
