# Original Cross Gate area music

The thirteen `cgbgm_*.mp3` streams come from the preserved client at
`../Magic Power/data/crossgate/source/BlueCrossgate/bin/bgm/`. The original WAVs
remain untouched. `provenance.json` records source and runtime SHA-256 hashes,
original durations and decoded frame counts. Preparation uses the existing
FFmpeg installation:

```sh
ffmpeg -i SOURCE.wav -c:a libmp3lame -q:a 2 OUTPUT.mp3
```

Keep the original 22050 Hz stereo, complete duration and gain. These are
compressed playback copies, not lossless masters. The thirteen files total
about 18.9 MiB. Do not substitute the client's `Blue_*` or other-game tracks.

`scripts/forest/crossgate_music.gd` owns selection. It preloads the streams;
the existing single music player loops them, retains its -9 dB mix and honors
Background Music, master volume and Sound Studio recording. Music remains off
by default for fresh settings. Existing saved preferences are preserved. Title,
character selection and initial Equipment stay silent until Enter Map.

| Location | Original file stem |
| --- | --- |
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

Map aliases resolve through the existing original-map source IDs. Joined Il
and Alyut use the existing village bounds, so walking into or out of them
changes theme without reloading the world. The two joined maps do one bounded
area check per physics step; a change swaps an already prepared stream. Normal
phase/map updates keep playback position when the theme is unchanged. Combat
keeps the area theme; separate battle/boss switching was not requested.

Evidence: original `bgm.cf` identifies sounds 200–204 (town/castle), 209–211
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
