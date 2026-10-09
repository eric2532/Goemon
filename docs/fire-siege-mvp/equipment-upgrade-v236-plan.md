# Fire Siege MVP v2.36 — equipment and skill follow-up

Continue directly from the user's latest v2.35 MVP, preserving previous changes.
The user authorized these additions on 9 October 2026:

- Dragon-shaped Dragoon helmet in his existing blue, teal and silver palette.
- Magical purple helmet for Magic Swordsman, keeping his face readable.
- Samurai red scarf wrapping neck and mouth, with a long wind-animated tail.
- Slightly fuller Ninja jaw, retaining the coordinated painted facial design.
- Airborne Dragoon Leap descends into a real ground impact. Wall contact and
  elapsed animation time must not cause a floating explosion. Retain the three
  blue impact pulses and the established grounded leap and higher normal jumps.
- Ranger fires three times as often, with arrows twice as large. Cadence was the
  stated default for the optional clarification and was used for implementation.
  Keep Samurai arrows and existing travel range unchanged.

Art, combat and the rendered test harness are implemented in parallel with
separate file ownership. Integration owns scarf deformation, animation, test
wiring, verification and packaging. Validate actual GLBs, four-angle in-game
views, scarf motion, landing collisions and Ranger timing. Export and test the
macOS MVP at v2.36.0 and preserve the previous installed app as a backup.

Completed: four editable character revisions, animated scarf, combat updates,
independent reviews, 686 source runtime checks, 1,929 art checks and 136 packaged
runtime checks, all passing. The installed app is v2.36.0; v2.35.0 is backed up.
