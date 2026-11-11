"""효과음 생성기. 8비트풍 소리를 직접 합성해 assets/audio/*.wav 로 저장한다.
실행: python3 tool/gen_sfx.py   (표준 라이브러리만 사용)"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
random.seed(7)

def osc(kind, phase):
    p = phase % 1.0
    if kind == 'square': return 1.0 if p < 0.5 else -1.0
    if kind == 'pulse': return 1.0 if p < 0.25 else -1.0
    if kind == 'tri': return 4 * abs(p - 0.5) - 1
    if kind == 'saw': return 2 * p - 1
    if kind == 'noise': return random.uniform(-1, 1)
    return math.sin(2 * math.pi * p)

def tone(f0, dur, kind='square', f1=None, vol=0.5, attack=0.004, decay=None):
    """f0→f1 로 미끄러지는 한 음. decay 가 있으면 그 시간 상수로 잦아든다."""
    n = int(RATE * dur); out = []; phase = 0.0
    for i in range(n):
        t = i / RATE
        f = f0 if f1 is None else f0 + (f1 - f0) * (i / n)
        phase += f / RATE
        env = min(1.0, t / attack) * min(1.0, (dur - t) / 0.012)
        if decay: env *= math.exp(-t / decay)
        out.append(osc(kind, phase) * vol * env)
    return out

def seq(*parts):
    out = []
    for p in parts: out += p
    return out

def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]

def rest(dur): return [0.0] * int(RATE * dur)

def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in samples))

N = lambda semis: 440.0 * 2 ** (semis / 12)   # A4 기준 반음

save('click', tone(N(12), 0.035, 'square', vol=0.3))
save('pour', mix(tone(520, 0.11, 'sine', f1=240, vol=0.5), tone(900, 0.05, 'noise', vol=0.12)))
save('early', tone(180, 0.05, 'tri', vol=0.5))
save('good', tone(N(7), 0.09, 'square', vol=0.3, decay=0.06))
for i in range(6):   # 콤보가 이어질수록 음이 올라간다
    base = 7 + i * 2
    save(f'perfect{i}', seq(tone(N(base), 0.055, 'pulse', vol=0.32),
                            tone(N(base + 5), 0.055, 'pulse', vol=0.32),
                            tone(N(base + 12), 0.16, 'pulse', vol=0.32, decay=0.07)))
save('topping', tone(380, 0.09, 'sine', f1=900, vol=0.45))
save('serve', seq(tone(N(14), 0.05, 'square', vol=0.3), tone(N(19), 0.2, 'square', vol=0.3, decay=0.08)))
save('bonus', seq(*[tone(N(s), 0.06, 'pulse', vol=0.3) for s in (12, 16, 19)], tone(N(24), 0.25, 'pulse', vol=0.3, decay=0.1)))
save('burnt', mix(tone(160, 0.3, 'saw', f1=60, vol=0.4), tone(1, 0.22, 'noise', vol=0.25, decay=0.08)))
save('full', seq(tone(196, 0.06, 'square', vol=0.3), rest(0.04), tone(196, 0.06, 'square', vol=0.3)))
save('lost', seq(tone(N(-2), 0.12, 'tri', vol=0.5), tone(N(-7), 0.22, 'tri', vol=0.5, decay=0.12)))
save('rush', seq(*[tone(N(s), 0.07, 'square', vol=0.3) for s in (7, 7, 12, 16)], tone(N(19), 0.3, 'square', vol=0.3, decay=0.15)))
save('vip', seq(*[tone(N(s), 0.05, 'pulse', vol=0.3) for s in (19, 24, 28, 31)], tone(N(36), 0.3, 'pulse', vol=0.28, decay=0.12)))
save('buy', seq(tone(N(12), 0.05, 'square', vol=0.3), tone(N(17), 0.05, 'square', vol=0.3), tone(N(24), 0.18, 'square', vol=0.3, decay=0.08)))
save('start', seq(*[tone(N(s), 0.08, 'square', vol=0.3) for s in (3, 7, 10)], tone(N(15), 0.25, 'square', vol=0.3, decay=0.12)))
save('win', seq(*[tone(N(s), 0.1, 'pulse', vol=0.3) for s in (3, 7, 10, 15)], rest(0.03),
                tone(N(12), 0.1, 'pulse', vol=0.3), tone(N(15), 0.45, 'pulse', vol=0.3, decay=0.2)))
save('fail', seq(tone(N(3), 0.16, 'tri', vol=0.5), tone(N(0), 0.16, 'tri', vol=0.5), tone(N(-4), 0.4, 'tri', vol=0.5, decay=0.2)))
print('ok', len(os.listdir(OUT)), 'files')
