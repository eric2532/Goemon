# Azure Ember 2.5.0 validation

- Godot 4.6.1 macOS Metal renderer, Apple M3.
- Rendered source suite: 41 checks passed, zero failures and no engine errors.
- Exported app suite: 42 checks passed, zero gameplay failures, exit status 0.
- macOS universal release exported and ad-hoc signature verified with `codesign --verify --deep --strict`. Bundle version verified as 2.5.0.
- Verified radial stomp damage and cover, unchanged leap/return and queued presses, immediate fireballs, held T duration/release, Settings width/length, independent R shield preservation, smoke damage at both endpoints, disappearance/hop/reappearance, twelve random safe teleports, and dodge/pause/character cancellation.
- All four maps exercised with full populations. More than 300m pursuit and routing around a 12m solid wall passed. Initial navigation field build in release: 84ms, 11,827 reachable coast cells.
- Portal, stomp, held beam and smoke screenshots reviewed.
- Recording library and sound studio test source are byte-for-byte unchanged from the pre-change backup.

The exported renderer logged one particle-shader allocation warning during shutdown, after all checks completed. No gameplay script errors occurred. See `release.log` for the complete result.

Source backup and previous app archive: `backups/aoe-pursuit-edo/`.
