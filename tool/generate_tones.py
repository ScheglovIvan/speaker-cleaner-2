"""Generates the app's honest tone bank into `assets/audio/`.

Run from the Flutter project root:  python3 tool/generate_tones.py

Every file it writes is a real, mathematically-generated 16-bit PCM sine at the
frequency in its filename (`tone_<hz>.wav`) plus one logarithmic 20 Hz -> 20 kHz
sweep. Nothing here is a re-labelled clip: the Tone Generator plays exactly the
frequency it prints on screen. Tone lengths are snapped to a whole number of
cycles near 2 s so `ReleaseMode.loop` repeats them without a click at the seam.
"""

import math, struct, wave, os

# Always write into THIS Flutter project's assets, whatever the caller's cwd is.
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

SR = 44100
AMP = 0.5
OUT = "assets/audio"
os.makedirs(OUT, exist_ok=True)
FREQS = [63,125,250,500,1000,2000,4000,8000,16000]
def fade(samples, n=441):
    m = len(samples)
    for i in range(min(n,m)):
        g = i/n
        samples[i] = int(samples[i]*g)
        samples[m-1-i] = int(samples[m-1-i]*g)
def write_wav(path, samples):
    with wave.open(path,"w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
for f in FREQS:
    # snap length to a whole number of cycles near 2s so it loops seamlessly
    cycles = max(1, round(2.0 * f))
    total = int(round(cycles * SR / f))
    s = [int(AMP*32767*math.sin(2*math.pi*f*i/SR)) for i in range(total)]
    write_wav(f"{OUT}/tone_{f}.wav", s)
# logarithmic sweep 20 Hz -> 20 kHz over 12 s
T=12.0; f0,f1=20.0,20000.0; N=int(T*SR); K=math.log(f1/f0)
sweep=[]
for i in range(N):
    t=i/SR
    phase=2*math.pi*f0*(T/K)*(math.exp(K*t/T)-1)
    sweep.append(int(AMP*32767*math.sin(phase)))
fade(sweep, 2205)
write_wav(f"{OUT}/sweep_20_20000.wav", sweep)
print("generated", len(FREQS), "tones + sweep")
