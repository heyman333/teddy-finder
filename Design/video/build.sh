#!/bin/zsh
# 숏폼 조립. 실행: ./Design/video/build.sh  → Design/video/teddyfinder_short.mp4
set -e
cd "$(dirname "$0")"
BG=0xFCE3CC; F=30; O="-c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -r $F -an"
mkdir -p seg
# 앱 녹화 구간 → 둥근 화면으로 복숭아 배경 위에 배치 + 위쪽 캡션. args: out start dur speed caption
app() {
  ffmpeg -v error -y -ss $2 -t $3 -i ${6:-app.mov} -loop 1 -i cap/mask.png -loop 1 -i $5 -f lavfi -i color=${BG}:s=1080x1920:r=${F} -filter_complex "
    [0:v]setpts=PTS/${4},fps=${F},scale=718:1560[v];[1:v]format=gray,scale=718:1560[m];[v][m]alphamerge[r];
    [3:v][r]overlay=181:330:shortest=1[b];[b][2:v]overlay=0:-40:shortest=1,format=yuv420p" $=O -t $(echo "$3/$4" | bc -l) seg/$1.mp4
}
# 스틸 사진 → 천천히 줌 + 캡션. args: out image dur caption captionY zoomFrom zoomTo
still() {
  n=$(printf %.0f $(( $3 * F ))); ffmpeg -v error -y -loop 1 -i $2 -loop 1 -i $4 -filter_complex "
    [0:v]scale=1280:1920,crop=1080:1920,scale=2160:3840,zoompan=z='${6}+(${7}-${6})*on/${n}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${n}:s=1080x1920:fps=${F}[v];
    [v][1:v]overlay=0:${5},format=yuv420p" $=O -frames:v ${n} seg/$1.mp4
}
still s1 hook.png 3.5 cap/c1.png 1180 1.0 1.12
app   s2 3.0 2.6 1.0 cap/c2.png
app   s3a 7.0 4.6 1.6 cap/c3.png
app   s3b 19.2 4.2 1.4 cap/c3.png
app   s4 23.4 3.0 1.0 cap/c4.png
# 찾은 순간 클로즈업: 앱 화면에서 박스 주변(1320x2868 기준)을 잘라 전체 화면으로
ffmpeg -v error -y -ss 26.4 -t 2.2 -i app.mov -loop 1 -i cap/c4.png -filter_complex "
  [0:v]fps=${F},crop=660:1173:670:613,scale=1080:1920[v];[v][1:v]overlay=0:1300:shortest=1,format=yuv420p" $=O -t 2.2 seg/s4z.mp4
still s5 reunion.png 3.5 cap/c5.png 1180 1.12 1.0
# 본질: 리모컨·에어팟도 찾는다 (각각 찾는 순간 0.4초 전부터)
app   s7a 5.75 2.4 1.0 cap/c8.png remote.mov
app   s7b 3.55 2.6 1.0 cap/c9.png airpods.mov
# 엔딩 카드: 곰 얼굴 + 이름 + App Store
ffmpeg -v error -y -f lavfi -i color=${BG}:s=1080x1920:r=${F} -loop 1 -i ../splash_bear.png -loop 1 -i cap/c6.png -loop 1 -i cap/c7.png -filter_complex "
  [1:v]scale=560:-1[bear];[0:v][bear]overlay=(W-w)/2:520[a];[a][2:v]overlay=0:1020[b];[b][3:v]overlay=0:1230,format=yuv420p" $=O -t 2.8 seg/s6.mp4
# 이어 붙이고 마지막에 페이드아웃 + 무음 오디오 트랙(플랫폼 업로드 호환)
printf "file '%s.mp4'\n" s1 s2 s3a s3b s4 s4z s5 s7a s7b s6 > seg/list.txt
ffmpeg -v error -y -f concat -safe 0 -i seg/list.txt -f lavfi -i anullsrc=r=44100:cl=stereo -filter_complex "[0:v]fade=t=in:st=0:d=0.3[v]" -map "[v]" -map 1:a -shortest -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart teddyfinder_short.mp4
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 teddyfinder_short.mp4)
python3 bgm.py $D 12.975,20.7,23.475
ffmpeg -v error -y -i teddyfinder_short.mp4 -i bgm.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart tmp.mp4 && mv tmp.mp4 teddyfinder_short.mp4
ffprobe -v error -show_entries format=duration:stream=width,height -of compact teddyfinder_short.mp4
