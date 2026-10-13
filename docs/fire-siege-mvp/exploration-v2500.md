# Fire Siege Exploration Crosshair v2.50.0

Built with Godot 4.6.3. This separate macOS build keeps the crosshair, character effects and Ranger's spread, deviation and curved shots.

The standard defense field is 320 × 480 metres, with Sakura Grove, Neon Village and Ruined Watchpost. Explore during unlimited preparation; each area's supply cache gives 3 gold once per run. Use the shrine compass to return and hold Y for 3 seconds to begin a wave. Custom maps keep their authored bounds and layouts.

The main shrine is closer to the enemy entrance, with a 110-metre approach. Shrine health is 100 on Normal and 50 on Hard. Arriving enemies remain alive; up to twelve strike every 2.5 seconds on a clock separate from player combat. Others wait at distinct legal positions. Health persists between waves.

Press F near a completed arrow tower to spend 10 gold converting it to level 2 ice. Ice deals no damage and slows movement 40% for 2 seconds; repeated hits refresh without stacking. Arrow and ice towers each use 0.10 gold per second during battles. Keep damage towers or finish enemies with your hero.

The last ground tower row moved from z158 to z168 to avoid overlapping wall work areas. The third opening mine is at (-18,200), preserving three mines within 25 metres of the new start. Large shrine queues use additional bounded rings to keep distinct waiting positions.

Performance fixes cache unchanged construction feedback and combine completed tower geometry by material while retaining aiming, recoil, build animations and all model triangles. Towers select a new target only when a shot is due; exact firing cadence and current downstream priority are preserved. No protected character assets changed. Actual measurements and their limits are provided in PERFORMANCE.txt beside the app; dense battles can still dip below 60 FPS.

Gameplay source: `a64e9b2`. Source verification: 20 suites, 966 checks, zero failures. Rendered Low/Medium/High tour completed, including all caches, mixed towers, shrine hits and airborne Ranger. Final exported checks and a complete focused FPS pass remain pending during preparation; use the packaged manifest for final verification status.
