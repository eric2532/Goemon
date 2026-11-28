# Original Cross Gate area and battle music

The fifteen `cgbgm_*.mp3` streams and four PUK2 area streams come from the preserved client at
`../Magic Power/data/crossgate/source/BlueCrossgate/bin/bgm/`. The original WAVs
remain untouched. `provenance.json` records source and runtime SHA-256 hashes,
original durations and decoded frame counts. Preparation uses the existing
FFmpeg installation:

```sh
ffmpeg -i SOURCE.wav -c:a libmp3lame -q:a 2 OUTPUT.mp3
```

Keep the original sample rate (22050 Hz, or 44100 Hz for PUK2 ruins), stereo, complete duration and gain.
These compressed copies are for playback. Use the original client tracks listed below.

`scripts/forest/crossgate_music.gd` owns selection. It preloads the streams;
the existing single music player loops them, retains its -9 dB mix and honors
Background Music, master volume and Sound Studio recording. Music remains off
by default for fresh settings. Existing saved preferences are preserved. Title,
character selection and initial Equipment stay silent until Enter Map.

| Location | Original file stem |
| --- | --- |
| Nearby enemy encounter | `cgbgm_b0` |
| Nearby boss encounter | `cgbgm_b1` |
| Falan city, city shops and Falan Arena | `cgbgm_m1` |
| Castle and royal rooms | `cgbgm_m0` |
| Freyja fields, gate approaches and connecting roads | `cgbgm_f1` |
| Il, Alyut, Saint Laruka, Venoa and their houses | `cgbgm_m3` |
| Sokia coast, desert and Ghana roads | `cgbgm_f2` |
| Kili, Ghana and their houses | `cgbgm_m4` |
| Shalena roads and snowfields | `cgbgm_f0` |
| Jenova, Tina, Abanis, university and their rooms | `cgbgm_m2` |
| Cursed Maze | `cgbgm_d0` |
| Ordinary caves/mines | `cgbgm_d1` |
| Castle underground, Black Prayer, Laurence Tower, Bezerem maze | `cgbgm_d2` |
| Deep Snow Mountain Trail | `cgbgm_d3` |
| Ice Prison | `cgbgm_d4` |
| 法蘭城遺跡 and island ruined galleries (sound 232) | `puk2_haikyo` |
| 蓋雷布倫森林 and 溫迪爾平原 (228) | `puk2_field1` |
| 艾爾莎島 (229) | `puk2_mati` |
| Temple halls (230) | `puk2_sinden` |
| Island trial rooms (214 / 216), shared quest rooms (213) | `cgbgm_d2` / `cgbgm_d4` / `cgbgm_d1` |
| Time passage and source sound 218 rooms | Silence (`bgm.cf`: `-1 218 -2`) |

Elsa's 95 native container sound IDs are retained in its map catalog from the
pinned LS2MAP header at offset 56 (big-endian u16), and resolved through the
client's original `bgm.cf`. This replaces the previous generic cave fallback.
`python3 tools/prepare_elsa_music.py` rebuilds the four playback copies and
checks the decoded frame counts. The native grid headers and client WAVs remain
untouched. Normal Explore travel updates the same player; source silence uses
a null stream and does not change the user's music preference. The castle
round-trip fixture checks every route theme and silence with music enabled.

Map aliases resolve through the existing original-map source IDs. Joined Il
and Alyut use the existing village bounds, so walking into or out of them
changes theme without reloading the world. The two joined maps do one bounded
area check per physics step; a change swaps an already prepared stream. Normal
phase/map updates keep playback position when the theme is unchanged.

Combat uses `cgbgm_b0` for living native enemies within 16 map units. A live
boss within 32 map units takes priority with `cgbgm_b1`, the original standard
boss track. Every 0.25 active seconds, the game checks the native army's active
boss handles and makes one local spatial query for enemies. Both checks use 3D
distance. Idle dialogue hosts remain on the area theme. Each combat track holds
for four seconds after its last detection. Remaining nearby enemies can keep
the regular battle theme playing after a boss goes down. Once combat ends,
the game resumes the area's saved playback position if the area theme still
matches. Pauses freeze the timers. Preparation, map travel and returning to
title clear them. The same player honors mute, master volume and recording pause.

The original `bgm.cf` identifies sounds 200–204 (town/castle), 205
(`cgbgm_b0`), 206 (`cgbgm_b1`), 209–211
(fields), 212–216 (dungeons). The pinned
[server dungeon table](https://github.com/linv2/Crossgate_Docker/blob/dd8690ed3df11e4eb5a038a54079a8f40d8e93b3/gmsv/data/dungeonconf.txt)
assigns sound 214 to Black Prayer, Laurence Tower and Bezerem, and 213 to the
forest maze. Source snapshots are under
`build/Other Files/Asset Toolkit/Cross Gate Music/Source/`.

Regional associations were cross-checked against the
[Cross Gate soundtrack catalog](https://w.atwiki.jp/gamemusicbest100/pages/1837.html).
This is not a recovered per-floor original server music table: special dungeon
overrides not listed above currently use `d1` and still need original playback
evidence. Keep that limitation explicit when extending the catalog.

Verify through `Play Goemon.command --script
res://tests/forest-shrine/building_music_test.gd`; add `--headless` for routing
and preference checks. The rendered run also captures Master output with SFX
muted temporarily, then restores the SFX bus. Logs, screenshots and audio stay
in the music toolkit folder. No app export is needed for iteration.
