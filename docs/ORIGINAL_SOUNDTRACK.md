# Original mobile-score prototypes

## Current creative status

An original, locally composed and rendered **prototype** score, not a final mixed soundtrack. The user liked the first title audition and asked for it to be downloadable. That direction is being continued at no cost. The first user listening audition is `House Kitty Heroes`, 58.18 seconds of music at 132 BPM in D minor (58.23 seconds in the MP3 preview due to encoder padding). It is an actual audio file, not a prompt or a claim that music has been generated elsewhere.

No Suno or ElevenLabs generation has been charged or run. An ElevenLabs estimate for one audition was obtained, but requires specific spending approval before generation. That estimate is not an audio deliverable.

## User review correction

The user later rejected much of the 18-cue set as insufficiently genre-specific, particularly the supposed UK garage. Prior enthusiasm applied to the title audition and must not be taken as approval of the full set. These old world cues are superseded creative prototypes, not final soundtrack choices. Three independently arranged short genre auditions are now produced by `scripts/compose_genre_auditions.py` outside the native asset directory: two-step UK garage, bossa/lounge arcade, and festival acid/big beat. They have not silently replaced game assets. Select directions by listening before expanding them.

## Musical direction and prompt-sheet assessment

The user supplied `Bill Dodgers soundtrack.html`, whose embedded DATA contains 18 core cues (12 screen/shared cues plus six world themes),48 stage-specific variants and a separate SFX list. Its identity is strong: London garage/breakbeats for the street; supermarket bossa/funk/lounge; festival big-beat, acid and rave piano; Balearic holiday textures; moving-day ska with cardboard percussion; and darker industrial electro for the Bill-ding.

Recommended next creative step: audition the title, World 1 and shared boss before commissioning 66 tracks. Keep a recognisable short melodic call across the title, world arrangements and ending. Ask for instrumentation, rhythm, energy and restrained lead density, rather than packing each prompt with many competing instruments and scene details. Gameplay loops need steady eight/sixteen-bar sections and musical seam editing; simply restarting a two-to-three-minute song does not establish a seamless loop. Request high-quality masters where available and test rhythm, tempo, voice exclusions and phone-speaker balance rather than assuming a prompt enforces them.

The sheet's subscription prices, promotions and licence statements are external claims that must be verified against current official terms before commercial use. A licence to use output does not by itself guarantee copyright exclusivity or that a generation never resembles other music. No rights or terms acceptance is claimed by these prototypes.

## Composition and provenance

`scripts/compose_soundtrack.py` defines explicit original scale-degree melodies, chords, bass rhythms, percussion and arrangements. A shared five-note call unifies a 32-bar theme/development/contrast/return structure, with shorter supporting cues. The motif is newly authored rather than copied from the web game's eight-bar C-Am-F-G tune. Each setting uses its own key, tempo and palette based on the user's prompt sheet.

All sounds are synthesized locally from additive oscillators and deterministic filtered noise. No third-party recordings, sample packs, commercial tracks, named-artist style imitation or generated-service audio are included. The instruments are deliberately synthetic: brass-like, electric-keyboard-like, rounded pulse, pluck, mallet, bass and percussion. They do **not** claim to be convincing recorded guitar, acoustic orchestra or a finished commercial mix. This is a reproducible no-cost arcade alternative for audition and native integration.

`score_manifest.json` records titles, tempos, keys, loop flags, exact sample counts, measured peaks/RMS/seam steps/mono correlation, byte sizes and SHA-256 for each encoded cue. Raw 44.1 kHz stereo WAV masters are generated into a requested output folder, by default a temporary build directory. Compact Vorbis masters and self-contained Godot resources are in `godot/assets/music/`.

## Cue coverage

- Title, character select, map, opening story, quiet comic underscore, party mode, victory, game over and ending.
- Six world themes, shared boss, separate final boss and bonus.
- Victory, gameover and ending play once. Other cues loop at their musical boundaries.
- A supporting cue existing does not mean its mode has been implemented in the native game. Party music is an asset, not multiplayer certification.

This is 18 core prototype cues, not all 48 per-level variants. Existing source arcade SFX stay unchanged.

## Native integration

`original_score.gd` extends `game_audio.gd`, retaining its effect APIs and source-music fallback. It is optional: change the host's GameAudio preload to this adapter only when ready to audition the score in-game. Call `set_level(level_id)` before `start_music(false)` at each load. Existing `start_music(true)` chooses shared boss, or final boss on 6-6. Bonus IDs use the bonus cue. Source `music_stream()` still returns the original WAV loops for parity checks.

Additional APIs: `start_title()`, `start_ending()`, `play_cue(name) -> bool`. Existing stop, mute, pause, effects and shutdown work unchanged. Transition music uses exactly two bounded players with 180 ms linear crossfades, frozen when paused. Gameplay music has a default -18 dB runtime trim, while menu/credits and screen cues use -9 dB. The original procedural music measures about -40.9 dBFS RMS and -20.6 dBFS peak; prototype assets peak around -2 dBFS, so a -18 dB gameplay trim roughly matches transient headroom instead of drowning the unchanged source effects. Tune this with headphones and real phone speakers, not solely by meters.

Build resources after composing:

```
python3 scripts/compose_soundtrack.py
HOME=<isolated> godot --headless --path godot --script res://tools/build_original_score.gd
HOME=<isolated> godot --headless --path godot --script res://tests/test_original_score.gd
```

The native `.res` files contain their Vorbis data and loop metadata, requiring no external URL or import step at runtime. Package those resources; source `.ogg` files can be excluded from native exports if size matters. Neither generation-time dependencies nor raw WAV masters are needed on the phone. No gameplay or original HTML files are changed by this score work.

## Verification limits

Verified suites: `test_original_score.gd` has 141 passing checks; `test_original_score_integration.gd` has 186 passing actual-main lifecycle checks across all 42 stage loads, six actual boss entry routes, World 6 miniboss restoration, pause/mute/Continue/story/clear, and title/credits focus handling. Boss/campaign completion fixtures are explicitly seeded for audio dispatch and are not gameplay clear evidence. The original `test_audio.gd -- --require-prebuilt` retains 154 passing assertions for all 22 unchanged source resources. `test_original_score_pack.gd` builds a minimal pack and passes 92 checks from an empty project directory with no source OGG, manifest or original project scripts present. Its 18 `.res` resources decode independently.

Automated checks cover decoding, non-silent finite audio, no full-scale clipping, bounded lengths, stereo/mono safety, numerical loop seam, all 18 resource load/cache/loop flags, family/boss routing, transitions, pause/mute/shutdown and retained source effects. Numeric seam and signal checks do not replace listening. Human musical review, loudness balancing under active combat, long-session fatigue testing, native exported-pack inspection and physical-device listening remain required before calling it final.

Headless lifecycle tests allow the Dummy mixer to consume a real playback quantum before replacing streams and to retire playback references before exit. Zero-time start/stop bursts initially exposed asynchronous engine-retirement warnings; repeated timed strict runs finish without warnings, resource leaks or errors. No gameplay timer change was used to suppress this.

## Melody-forward development

The next user request prioritises memorable stage melodies and later full-song expansion. `scripts/compose_melodic_auditions.py` produces two independent theme studies outside native assets: Back Our Way (street, F minor, 132 BPM, 58.18 seconds) and A Little Change (shop, E-flat major, 120 BPM, 64 seconds). Each uses a deliberately authored four-bar question/answer, repeated A material, a contrasting B section and a developed return, rather than relying only on genre percussion. MIDI melody guides preserve the notes and timing for later arrangement. No existing game soundtrack was transcribed, no paid generation was used, and the studies are not automatically approved or installed game assets.
