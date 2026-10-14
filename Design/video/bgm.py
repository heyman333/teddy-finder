# 저작권 걱정 없는 배경음(표준 라이브러리만). 사용: python3 bgm.py <길이초> <띠링 시각들, 쉼표 구분>
import wave, struct, math, sys
SR=44100; D=float(sys.argv[1]); chimes=[float(x) for x in sys.argv[2].split(",")]
N=int(SR*D); buf=[0.0]*N
def pluck(t0, f, dur=0.35, amp=0.18):
    s=int(t0*SR)
    for i in range(int(dur*SR)):
        if s+i>=N: break
        t=i/SR; e=math.exp(-t*9)
        buf[s+i]+=amp*e*(math.sin(2*math.pi*f*t)+0.35*math.sin(4*math.pi*f*t)+0.12*math.sin(6*math.pi*f*t))
note=lambda m: 440*2**((m-69)/12)
prog=[[60,64,67,72],[57,60,64,69],[53,57,60,65],[55,59,62,67]]  # C Am F G
beat=0.25; t=0.0; k=0
while t<D-2.8:
    ch=prog[(k//8)%4]; pluck(t, note(ch[[0,2,1,2,3,2,1,2][k%8]]), amp=0.14)
    if k%2==0: pluck(t, note(ch[0]-12), 0.25, 0.10)
    t+=beat; k+=1
for c in chimes:
    for i,m in enumerate([84,88,91,96]): pluck(c+i*0.07, note(m), 0.6, 0.16)
for i,m in enumerate([72,76,79,84]): pluck(D-2.6+i*0.12, note(m), 1.2, 0.15)
peak=max(abs(x) for x in buf) or 1; fade=int(SR*0.6)
with wave.open('bgm.wav','w') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b''.join(struct.pack('<h', int(32767*0.8*x/peak*min(1,(N-i)/fade))) for i,x in enumerate(buf)))
