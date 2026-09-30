# Goemon v2.12.0 validation

- Rendered priority/dash suite: 40 checks passed, including real audio playback progressing through crowd hit spam.
- Chain weapon regression: 29 checks passed.
- Edo firecaster regression: 49 checks passed.
- Rendered Sound Studio regression: 15 checks passed; synthetic audio captured with zero dropped frames. No room audio recorded.
- Exported Mac application priority/dash suite: 39 checks passed (headless skips real mixer clock assertion).
- macOS release export succeeded; universal app version 2.12.0; deep/strict code signature verification passed.
- Inspected dash and updated controls screenshots.

The initial headless run in gameplay.log failed only the playback-clock assertion because the dummy audio driver does not advance that clock. The test now checks playback continuity in both modes and mixer-clock advancement in the rendered run. Both final runs pass. Existing headless chain/firecaster shutdown resource warnings remain; rendered priority/dash and packaged tests exited cleanly.

Previous source and v2.11 app/ZIP are preserved in backups/priority-dash/.
