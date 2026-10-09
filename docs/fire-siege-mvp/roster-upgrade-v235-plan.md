# Fire Siege MVP v2.35 — roster and combat upgrade

The user approved this scope after reviewing the seven-item restatement on
9 October 2026. Continue in the existing MVP worktree and preserve its movement,
combat, building and accepted v2.34.1 art changes. No remote release is requested.

## Behavior and art

- Triple current basic-attack reach/projectile travel for all twelve heroes.
  Apply growth once and preserve heavy/utility range and terrain blocking.
- After Magic Swordsman's second jump, basic attack commits a fast forward/down
  slash with a large violet energy impact and high damage, once per landing.
- Pirate's heavy shot becomes a visible projectile with ten times the previous
  bullet diameter, piercing successive enemies without repeat hits.
- Ninja and Explorer earn 20 energy per completed light attack. At 100, one
  manual RMB/3 heavy can bypass cooldown and consumes the credit on successful
  use. Normal cooldown attacks remain available. Show a small energy bar and
  clear energy on death, run reset and hero changes.
- Dragoon reaches twice the normal jump height; scale launch speed by sqrt(2).
- All Mage fireball charge tiers travel straight through successive enemies.
- Extend the accepted head/face/hair direction to the remaining eight Rogue
  heroes. Preserve the two pilots and Goemon master, painted identities, native
  pivots and equipment. Review front, profile, three-quarter and gameplay views.

## Execution and ownership

- [x] Art: roster sculpt/export generator, editable sources, GLBs, portraits;
  validate mesh/UV correctness and render all views beside Goemon.
- [x] Rogue combat: facade, actions, actor poses, effects, energy HUD and ability
  descriptions; behavioral tests for ranges, piercing, jump apex, dive lifecycle
  and earned heavy activation/cancellation.
- [x] Native combat: Goemon pipe/coin and Edo volley/empowered primary range;
  boundary hit tests, unchanged heavy range, growth and cover checks.
- [x] Integration: real-MVP rendered tour of all ten Rogue faces and new skills;
  focused regression suites plus independent final review.
- [x] Delivery: export and test v2.35.0 macOS app, preserve v2.34.1 backup, install
  at the existing launch path, and record verification and artifact paths.

## Review focus

Review enlarged attacks near walls; one hit per projectile target; no energy
from cancelled/blocked actions or held-input bonus repetition; aerial dive
interruption, landing and hero-switch cleanup; face UVs and headwear fit in
profile; exact preservation of accepted pilot/Goemon art.

Baseline copies and verification evidence: `build/rogue-roster-upgrade/`.
