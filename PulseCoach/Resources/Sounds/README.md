# Custom Audio Cues Directory (`Resources/Sounds/`)

Drop any of the following optional `.mp3` files into this folder (`PulseCoach/Resources/Sounds/`) and they will be bundled automatically by XcodeGen and played by `AudioEngine`:

### Studio Voice Cues
- `voice_3.mp3`
- `voice_2.mp3`
- `voice_1.mp3`
- `voice_work.mp3`
- `voice_rest.mp3`
- `voice_done.mp3`

### Sound Effects (SFX) Cues
- `sfx_countdown_beep.mp3`
- `sfx_beep_work.mp3`
- `sfx_beep_rest.mp3`
- `sfx_whistle_work.mp3`
- `sfx_whistle_rest.mp3`
- `sfx_ring_work.mp3`
- `sfx_ring_rest.mp3`
- `sfx_gong_work.mp3`
- `sfx_gong_rest.mp3`
- `sfx_chime_work.mp3`
- `sfx_chime_rest.mp3`

**Safety Fallback:** Any file not present in this directory automatically falls back to `AVSpeechSynthesizer` (for Studio Voice cues) or in-memory studio-synthesized PCM waveforms (for Beep, Whistle, Ring, Gong, Calm Chime, and Countdown Beep).
