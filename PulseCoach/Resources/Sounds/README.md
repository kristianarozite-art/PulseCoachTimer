# Custom Audio Cues Directory (`PulseCoach/Resources/Sounds/`)

`AudioEngine` supports **both `.mp3` and `.wav`** files in this directory (checking `.mp3` first, then `.wav`). Any file placed here is bundled into `PulseCoach.app/Sounds/` by XcodeGen.

During GitHub Actions builds (`.github/workflows/build-ios.yml`), `scripts/generate_voice_cues.py` automatically runs `edge-tts` (`en-US-AndrewNeural`, rate `+15%`, pitch `+2Hz`) + `ffmpeg` (leading silence trimmed & volume normalized) to generate the 6 studio voice `.mp3` files if they are not already present in this folder.

### 1. Studio Voice Cues (`.mp3` or `.wav`)
| Filename (`.mp3` or `.wav`) | Spoken Cue | When Triggered |
| :--- | :--- | :--- |
| `voice_3.mp3` / `voice_3.wav` | `"Three!"` | 3 seconds remaining in phase (when 3-2-1 Countdown is ON) |
| `voice_2.mp3` / `voice_2.wav` | `"Two!"` | 2 seconds remaining in phase (when 3-2-1 Countdown is ON) |
| `voice_1.mp3` / `voice_1.wav` | `"One!"` | 1 second remaining in phase (when 3-2-1 Countdown is ON) |
| `voice_work.mp3` / `voice_work.wav` | `"Work!"` | Start of every Work phase |
| `voice_rest.mp3` / `voice_rest.wav` | `"Rest!"` | Start of every Standard Rest or Transition Rest phase |
| `voice_done.mp3` / `voice_done.wav` | `"Workout complete!"` | Workout completion (`DONE`) |

### 2. Sound Effects (SFX) Cues (`.mp3` or `.wav`)
| Filename (`.mp3` or `.wav`) | Style | When Triggered |
| :--- | :--- | :--- |
| `sfx_countdown_beep.mp3` / `.wav` | All SFX Styles | 3-2-1 countdown ticks (short beep) & Get Ready start |
| `sfx_beep_work.mp3` / `.wav` | **Beep** | Start of Work phase |
| `sfx_beep_rest.mp3` / `.wav` | **Beep** | Start of Rest / Transition Rest phase |
| `sfx_whistle_work.mp3` / `.wav` | **Whistle** | Start of Work phase |
| `sfx_whistle_rest.mp3` / `.wav` | **Whistle** | Start of Rest / Transition Rest phase |
| `sfx_ring_work.mp3` / `.wav` | **Ring** | Start of Work phase |
| `sfx_ring_rest.mp3` / `.wav` | **Ring** | Start of Rest / Transition Rest phase |
| `sfx_gong_work.mp3` / `.wav` | **Gong** | Start of Work phase |
| `sfx_gong_rest.mp3` / `.wav` | **Gong** | Start of Rest / Transition Rest phase |
| `sfx_chime_work.mp3` / `.wav` | **Calm Chime** | Start of Work phase |
| `sfx_chime_rest.mp3` / `.wav` | **Calm Chime** | Start of Rest / Transition Rest phase |
