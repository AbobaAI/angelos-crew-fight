#!/bin/bash
# Synthesises every crew-fight sound with ffmpeg (no samples): run in this folder to rebuild.
# Output: 44.1 kHz 16-bit mono WAV, normalised to a modest peak.
set -e
cd "$(dirname "$0")"
N='(random(0)*2-1)'
g() { # name duration expr [extra filters]
  ffmpeg -v error -y -f lavfi -i "aevalsrc='$3':s=44100:d=$2" -af "${4:+$4,}alimiter=limit=0.7,aformat=sample_fmts=s16:channel_layouts=mono" "$1.wav"
}
g punch    0.25 "(0.9*sin(2*PI*(120*t-200*t*t))+0.45*$N*exp(-60*t))*exp(-16*t)" "lowpass=f=2500"
g slap     0.16 "$N*exp(-38*t)" "highpass=f=1400,lowpass=f=7000"
g crack    0.30 "(0.8*$N*exp(-70*t)+0.6*sin(2*PI*900*t)*exp(-30*t))" "highpass=f=300"
g homerun  0.90 "0.8*$N*exp(-70*t)+0.35*sin(2*PI*(600*t+900*t*t))*exp(-2.5*t)"
g splat    0.35 "$N*(0.6+0.4*sin(2*PI*30*t))*exp(-12*t)" "lowpass=f=900"
g feedback 0.60 "0.5*sin(2*PI*2800*t)*min(1,t*8)*exp(-3*t)+0.2*sin(2*PI*2803*t)*min(1,t*6)*exp(-3*t)"
g boom     0.55 "sin(2*PI*(70*t-20*t*t))*exp(-6*t)+0.3*$N*exp(-40*t)" "lowpass=f=600"
g clack    0.06 "$N*exp(-120*t)+0.4*sin(2*PI*2400*t)*exp(-150*t)" "highpass=f=2500"
g keys     0.32 "($N*exp(-120*t)+$N*exp(-120*(t-0.1))*gte(t,0.1)+$N*exp(-120*(t-0.21))*gte(t,0.21))" "highpass=f=2500"
g thud     0.30 "sin(2*PI*70*t)*exp(-14*t)+0.3*$N*exp(-25*t)" "lowpass=f=500"
g zap      0.35 "sin(2*PI*(1500*t-2000*t*t))*exp(-5*t)*(0.7+0.3*sin(2*PI*60*t))"
g whoosh   0.25 "$N*sin(PI*t/0.25)" "bandpass=f=900:w=700"
g crit     0.50 "0.5*sin(2*PI*1320*t)*exp(-6*t)+0.35*sin(2*PI*1980*t)*exp(-7*t)+0.5*$N*exp(-50*t)"
g ko       1.20 "0.6*sin(2*PI*(400*t-150*t*t))*exp(-1.5*t)+sin(2*PI*55*t)*exp(-4*t)+0.4*$N*exp(-20*t)" "lowpass=f=3000"
g gong     2.50 "0.5*sin(2*PI*220*t)*exp(-1.2*t)+0.35*sin(2*PI*563*t)*exp(-1.8*t)+0.25*sin(2*PI*924*t)*exp(-2.5*t)+0.15*sin(2*PI*1310*t)*exp(-3.5*t)"
g bell     0.90 "(0.5*sin(2*PI*1200*t)+0.3*sin(2*PI*1830*t))*exp(-9*t)+(0.5*sin(2*PI*1200*(t-0.3))+0.3*sin(2*PI*1830*(t-0.3)))*exp(-9*(t-0.3))*gte(t,0.3)"
g cheer    2.20 "$N*sin(PI*t/2.2)*(0.8+0.2*sin(2*PI*7*t))" "bandpass=f=1500:w=1800"
g sting    0.50 "0.5*sin(2*PI*523*t)*lt(t,0.13)+0.5*sin(2*PI*659*t)*gte(t,0.13)*lt(t,0.26)+0.5*sin(2*PI*784*t)*gte(t,0.26)*exp(-5*(t-0.26))" "lowpass=f=4000"
g swoosh   0.60 "$N*sin(PI*t/0.6)" "highpass=f=1200"
g blip     0.25 "0.5*sin(2*PI*880*t)*lt(t,0.1)+0.5*sin(2*PI*660*t)*gte(t,0.12)*exp(-8*(t-0.12))"
# fanfare: proper notes (C5 G5 C6 E6 held)
ffmpeg -v error -y -f lavfi -i "aevalsrc='(lt(t,0.18)*sin(2*PI*523*t)+gte(t,0.2)*lt(t,0.38)*sin(2*PI*784*t)+gte(t,0.4)*lt(t,0.58)*sin(2*PI*1047*t)+gte(t,0.6)*sin(2*PI*1319*t)*exp(-1.4*(t-0.6)))*(1+0.4*sin(2*PI*5*t)*gte(t,0.6))*0.45':s=44100:d=1.7" -af "aecho=0.8:0.5:60:0.3,alimiter=limit=0.7,aformat=sample_fmts=s16:channel_layouts=mono" fanfare.wav
# crowd ambience loop (6 s, pink noise, soft)
ffmpeg -v error -y -f lavfi -i "anoisesrc=color=pink:amplitude=0.5:d=6:r=44100" -af "lowpass=f=1400,highpass=f=150,volume=0.5,aformat=sample_fmts=s16:channel_layouts=mono" crowd.wav
ls *.wav | wc -l
# peak-normalise: one-shots to -6 dBFS, the crowd loop to -14 dBFS
for f in *.wav; do
  t=-6; [ "$f" = crowd.wav ] && t=-14
  m=$(ffmpeg -v info -i "$f" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \([-0-9.]*\) dB/\1/p')
  ffmpeg -v error -y -i "$f" -af "volume=$(python3 -c "print($t-($m))")dB" -c:a pcm_s16le "n_$f" && mv "n_$f" "$f"
done
