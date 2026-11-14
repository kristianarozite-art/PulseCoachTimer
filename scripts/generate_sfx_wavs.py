import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
TARGET_PEAK_DBFS = -1.0
TARGET_PEAK_LINEAR = 10.0 ** (TARGET_PEAK_DBFS / 20.0)  # ~0.89125


def normalize_and_save_wav(filepath: Path, samples: list[float]) -> None:
    filepath.parent.mkdir(parents=True, exist_ok=True)
    peak = max((abs(s) for s in samples), default=1.0)
    if peak < 1e-9:
        peak = 1.0
    scale = (TARGET_PEAK_LINEAR / peak) * 32767.0

    # Apply 10ms fade-out at very end to prevent any DC click
    fade_samples = min(int(0.010 * SAMPLE_RATE), len(samples))
    n = len(samples)

    pcm_bytes = bytearray(n * 2)
    for i, s in enumerate(samples):
        env = 1.0
        if i >= n - fade_samples and fade_samples > 0:
            env = (n - 1 - i) / float(fade_samples)
        val = int(round(s * env * scale))
        if val > 32767:
            val = 32767
        elif val < -32768:
            val = -32768
        struct.pack_into("<h", pcm_bytes, i * 2, val)

    with wave.open(str(filepath), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(pcm_bytes)

    size_kb = filepath.stat().st_size / 1024.0
    duration = n / float(SAMPLE_RATE)
    print(f"Generated {filepath.name:<24} ({duration:.2f}s, {size_kb:6.1f} KB, peak={TARGET_PEAK_DBFS} dBFS)")


def synth_countdown_beep() -> list[float]:
    # Short crisp 880Hz pip (~0.12s)
    duration = 0.12
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    harmonics = [(880.0, 1.0), (1760.0, 0.35), (2640.0, 0.12)]
    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.003)
        release = min(1.0, (duration - t) / 0.010)
        env = attack * release * math.exp(-6.0 * t)
        val = sum(amp * math.sin(2.0 * math.pi * freq * t) for freq, amp in harmonics)
        out[i] = val * env
    return out


def synth_beep_work() -> list[float]:
    # Energetic double-tone crisp high beep (~0.35s)
    duration = 0.35
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.10:
            lt = t
            seg_dur = 0.10
            freq = 1318.51  # E6
            attack = min(1.0, lt / 0.003)
            release = min(1.0, (seg_dur - lt) / 0.008)
            env = attack * release * math.exp(-4.5 * lt)
            out[i] = env * (
                1.0 * math.sin(2.0 * math.pi * freq * lt)
                + 0.40 * math.sin(2.0 * math.pi * freq * 2.0 * lt)
                + 0.18 * math.sin(2.0 * math.pi * freq * 3.0 * lt)
            )
        elif t >= 0.13:
            lt = t - 0.13
            seg_dur = 0.22
            freq = 1760.0  # A6
            attack = min(1.0, lt / 0.003)
            release = min(1.0, (seg_dur - lt) / 0.012)
            env = attack * release * math.exp(-3.8 * lt)
            out[i] = env * (
                1.0 * math.sin(2.0 * math.pi * freq * lt)
                + 0.45 * math.sin(2.0 * math.pi * freq * 2.0 * lt)
                + 0.20 * math.sin(2.0 * math.pi * freq * 3.0 * lt)
            )
    return out


def synth_beep_rest() -> list[float]:
    # Lower, softer double beep (~0.35s)
    duration = 0.35
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.11:
            lt = t
            seg_dur = 0.11
            freq = 659.25  # E5
            attack = min(1.0, lt / 0.004)
            release = min(1.0, (seg_dur - lt) / 0.010)
            env = attack * release * math.exp(-4.5 * lt)
            out[i] = env * (
                1.0 * math.sin(2.0 * math.pi * freq * lt)
                + 0.25 * math.sin(2.0 * math.pi * freq * 2.0 * lt)
            )
        elif t >= 0.14:
            lt = t - 0.14
            seg_dur = 0.21
            freq = 523.25  # C5
            attack = min(1.0, lt / 0.004)
            release = min(1.0, (seg_dur - lt) / 0.014)
            env = attack * release * math.exp(-4.2 * lt)
            out[i] = env * (
                1.0 * math.sin(2.0 * math.pi * freq * lt)
                + 0.22 * math.sin(2.0 * math.pi * freq * 2.0 * lt)
            )
    return out


def synth_whistle(duration: float, base_f1: float, base_f2: float) -> list[float]:
    # Realistic sports referee pea-whistle with ~35Hz trill modulation + breath noise
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    rng = random.Random(42)
    p1 = 0.0
    p2 = 0.0
    noise_state = 0.0

    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.010)
        release = min(1.0, (duration - t) / 0.025)
        trill = 0.68 + 0.32 * math.sin(2.0 * math.pi * 35.0 * t)
        env = attack * release * trill * math.exp(-0.6 * t)

        fm = 65.0 * math.sin(2.0 * math.pi * 35.0 * t)
        f1 = base_f1 + fm
        f2 = base_f2 - 0.5 * fm

        p1 += 2.0 * math.pi * f1 / SAMPLE_RATE
        p2 += 2.0 * math.pi * f2 / SAMPLE_RATE

        white = rng.uniform(-1.0, 1.0)
        noise_state = 0.82 * noise_state + 0.18 * white
        breath = (white - noise_state) * 0.14

        tone = (
            0.65 * math.sin(p1)
            + 0.35 * math.sin(p2)
            + 0.18 * math.sin(2.0 * p1)
            + breath
        )
        out[i] = tone * env
    return out


def synth_boxing_bell_strike(duration: float, f0: float) -> list[float]:
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    # Metallic boxing bell inharmonic modal ratios: (ratio, relative_amp, decay_rate)
    modes = [
        (1.000, 1.00, 3.2),
        (1.504, 0.72, 4.0),
        (2.000, 0.60, 4.8),
        (2.443, 0.48, 5.8),
        (2.918, 0.38, 7.2),
        (3.582, 0.28, 9.5),
        (4.231, 0.20, 12.5),
        (5.110, 0.14, 18.0),
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.0015)
        s = 0.0
        for ratio, amp, decay in modes:
            freq = f0 * ratio
            s += amp * math.exp(-decay * t) * math.sin(2.0 * math.pi * freq * t)
        # Initial metallic clapper transient (first 15ms)
        if t < 0.015:
            s += 0.35 * math.exp(-180.0 * t) * math.sin(2.0 * math.pi * 3400.0 * t)
        out[i] = s * attack
    return out


def synth_ring_work() -> list[float]:
    # Bright metallic boxing bell ding-ding! (~1.2s)
    duration = 1.20
    n = int(duration * SAMPLE_RATE)
    strike1 = synth_boxing_bell_strike(duration, 1046.50)
    strike2 = synth_boxing_bell_strike(duration - 0.21, 1085.0)
    offset = int(0.21 * SAMPLE_RATE)
    out = list(strike1)
    for i in range(len(strike2)):
        if i + offset < n:
            out[i + offset] += strike2[i] * 1.08
    return out


def synth_ring_rest() -> list[float]:
    # Single clear boxing bell strike (~1.0s)
    return synth_boxing_bell_strike(1.00, 932.33)


def synth_gong(duration: float, f0: float, shimmer_gain: float) -> list[float]:
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    # Deep resonant gong partials: (ratio, amp, decay)
    partials = [
        (0.500, 0.65, 1.4),
        (1.000, 1.00, 1.7),
        (1.260, 0.60, 2.1),
        (1.414, 0.72, 2.3),
        (1.587, 0.52, 2.6),
        (2.000, 0.45, 3.1),
        (2.245, 0.38, 3.6),
        (2.762, 0.30, 4.4),
        (3.185, 0.24, 5.2),
        (3.840, 0.18, 6.4),
    ]
    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.008)
        s = 0.0
        # Slight nonlinear pitch glide on heavy gong impact
        pitch_bend = 1.0 + 0.012 * math.exp(-10.0 * t)
        for ratio, amp, decay in partials:
            freq = f0 * ratio * pitch_bend
            s += amp * math.exp(-decay * t) * math.sin(2.0 * math.pi * freq * t)

        # Delayed high metallic shimmer bloom
        shimmer_env = (t / 0.14) * math.exp(-3.4 * t)
        shimmer = shimmer_gain * shimmer_env * (
            0.5 * math.sin(2.0 * math.pi * (f0 * 4.65) * t + 1.5 * math.sin(2.0 * math.pi * 14.0 * t))
            + 0.35 * math.sin(2.0 * math.pi * (f0 * 5.82) * t)
        )
        out[i] = (s + shimmer) * attack
    return out


def synth_chime_chord(duration: float, notes: list[tuple[float, float]]) -> list[float]:
    # notes: list of (start_time_sec, freq_hz)
    n = int(duration * SAMPLE_RATE)
    out = [0.0] * n
    harmonics = [(1.0, 1.0, 3.2), (2.0, 0.42, 4.8), (3.0, 0.18, 6.5), (4.0, 0.08, 9.0)]

    for start_t, freq in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        for i in range(start_idx, n):
            lt = (i - start_idx) / SAMPLE_RATE
            attack = min(1.0, lt / 0.005)
            tone = 0.0
            for mult, amp, decay in harmonics:
                tone += amp * math.exp(-decay * lt) * math.sin(2.0 * math.pi * (freq * mult) * lt)
            out[i] += tone * attack
    return out


def generate_all_sfx(sounds_dir: Path) -> None:
    normalize_and_save_wav(sounds_dir / "sfx_countdown_beep.wav", synth_countdown_beep())
    normalize_and_save_wav(sounds_dir / "sfx_beep_work.wav", synth_beep_work())
    normalize_and_save_wav(sounds_dir / "sfx_beep_rest.wav", synth_beep_rest())
    normalize_and_save_wav(sounds_dir / "sfx_whistle_work.wav", synth_whistle(0.60, 2880.0, 3115.0))
    normalize_and_save_wav(sounds_dir / "sfx_whistle_rest.wav", synth_whistle(0.35, 2720.0, 2940.0))
    normalize_and_save_wav(sounds_dir / "sfx_ring_work.wav", synth_ring_work())
    normalize_and_save_wav(sounds_dir / "sfx_ring_rest.wav", synth_ring_rest())
    normalize_and_save_wav(sounds_dir / "sfx_gong_work.wav", synth_gong(1.80, 196.00, 0.42))
    normalize_and_save_wav(sounds_dir / "sfx_gong_rest.wav", synth_gong(1.40, 164.81, 0.25))
    normalize_and_save_wav(
        sounds_dir / "sfx_chime_work.wav",
        synth_chime_chord(1.00, [(0.00, 523.25), (0.10, 659.25), (0.20, 783.99), (0.30, 1046.50)]),
    )
    normalize_and_save_wav(
        sounds_dir / "sfx_chime_rest.wav",
        synth_chime_chord(1.00, [(0.00, 783.99), (0.13, 659.25), (0.26, 523.25)]),
    )


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    target_dir = repo_root / "PulseCoach" / "Resources" / "Sounds"
    generate_all_sfx(target_dir)
