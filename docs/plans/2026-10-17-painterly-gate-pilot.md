# Painterly gate pilot

Approved scope: one existing main gate and its nearest western watch tower. Hand-painted moss/earth ground, weathered wood and slate, warm lanterns and cooler soft shadows. Characters, combat, stats, map documents, navigation and collision shapes stay unchanged.

Implementation: reversible presentation helper, localized ground/road shader, render-only trim and stones. Building-view comparison button. Ordinary export defaults to original; a separate painterly export defaults to preview. No user map/settings writes. Source experiment isolated on codex/painterly-gate-preview; current Goemon.app is preserved.

Validation: toggle/reload invariants (map, collisions and material restoration), native A/B images, combat/map regressions, independent code review, signed separate app boot and original package hash check.
