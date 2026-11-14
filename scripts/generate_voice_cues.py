import asyncio
import shutil
import subprocess
import tempfile
from pathlib import Path

import edge_tts

VOICE = "en-US-AndrewNeural"
RATE = "+15%"
PITCH = "+2Hz"

CUES = {
    "voice_3.mp3": "Three!",
    "voice_2.mp3": "Two!",
    "voice_1.mp3": "One!",
    "voice_work.mp3": "Work!",
    "voice_rest.mp3": "Rest!",
    "voice_done.mp3": "Workout complete!",
}


def find_ffmpeg() -> str | None:
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        pass
    return shutil.which("ffmpeg")


async def synthesize_all(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    ffmpeg_bin = find_ffmpeg()
    print(f"Using voice: {VOICE} (rate={RATE}, pitch={PITCH})")
    print(f"FFmpeg binary: {ffmpeg_bin or 'Not found (using raw edge-tts stream)'}")

    for filename, text in CUES.items():
        target_path = output_dir / filename
        if target_path.exists() and target_path.stat().st_size > 1024:
            print(f"Skipping {filename} (already exists, {target_path.stat().st_size} bytes)")
            continue

        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
            tmp_path = Path(tmp.name)

        try:
            communicate = edge_tts.Communicate(text=text, voice=VOICE, rate=RATE, pitch=PITCH)
            await communicate.save(str(tmp_path))

            if ffmpeg_bin:
                # Trim leading silence and normalize loudness so cues fire instantaneously at 0ms
                cmd = [
                    ffmpeg_bin,
                    "-y",
                    "-i",
                    str(tmp_path),
                    "-af",
                    "silenceremove=start_periods=1:start_duration=0.005:start_threshold=-42dB,volume=1.4,alimiter=limit=0.95",
                    "-ar",
                    "44100",
                    "-ac",
                    "1",
                    "-b:a",
                    "128k",
                    str(target_path),
                ]
                subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                shutil.move(str(tmp_path), str(target_path))

            size_kb = target_path.stat().st_size / 1024.0
            print(f"Generated {target_path.name} ({size_kb:.1f} KB) -> \"{text}\"")
        finally:
            if tmp_path.exists():
                tmp_path.unlink(missing_ok=True)


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    sounds_dir = repo_root / "PulseCoach" / "Resources" / "Sounds"
    asyncio.run(synthesize_all(sounds_dir))
