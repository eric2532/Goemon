# Cross Gate pet stance indicators

Unchanged original Joy UI art decoded from the preserved Magic Power library
using `tools/cg_library.py` → `image_from_record("joy", row)`. No cropping,
recoloring or new artwork. The source library/client remains untouched.

| Goemon stance | Original label | Normal row | Selected row |
| --- | --- | ---: | ---: |
| G: attack | 攻擊 (attack) | 341 | 342 |
| F: defend in place | 防禦 (defend) | 353 | 354 |
| H: back / follow | 收回 (recall) | 366 | 368 |

The recall artwork is reused as a follow-order indicator in Goemon; it is not
claimed to be an original Cross Gate follow stance. Default automatic escort
and the H return order both light the Back indicator. These are status indicators,
not extra clickable commands. The native army retains all stance behavior.

`provenance.json` records dimensions and pixel/PNG hashes. To recover, add
`/Users/eric/Desktop/Projects_Codex/Magic Power/tools` to Python's module path,
import `cg_library`, decode the listed rows and save unchanged PNGs. Assets are
imported losslessly with alpha-border rewriting disabled, and are
preloaded once by the existing Forest HUD, with original selected variants used
for the current command. No archive access or image creation occurs in play.

The HUD reads Attack, Defend, Back from left to right; G/F/H retain their native
orders. P separately toggles the selected pack, cancelling queued summons and
retiring live selected companions through the native owner on the second press.
