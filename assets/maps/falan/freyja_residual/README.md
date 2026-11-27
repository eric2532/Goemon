# Freyja near-city source surface repair

`python3 tools/prepare_freyja_residual_surface.py` prepares these derivatives;
add `--check` for original source, mask, art-hash and derivative checks.
The input is original client `BlueCrossgate/map/0/100.dat`, 840×610, plus the
preserved West/East/South approach and Falan city masks. The source checksum,
all repaired cells, blocked rectangles and native shore anchors are in `provenance.json`.

The initial 1,252 decoder-open-cell notch is source x408–439,y36–134. It
contains 942 dry cells and 310 water cells. Presentation recovers the coherent
recorded band x408–439,y36–138, including blocked dry ground and recorded
water, rather than drawing only decoder-open islands. West repairs 2,356
cells (1,202 dry,168 shore caps,986 water); East repairs 2,341 (1,188/167/986).
Their distinct city frames retain 159 and150 opaque city stations. Existing
opaque exterior pixels remain untouched. Shore caps use the established East
field interpretation; source water is not silently changed to land.

`data.gd::surface()` copies the original imported base RGBA and applies only
the prepared exception bounds once. This preserves even transparent RGB,
which the legacy terrain coverage code reads. It reuses the existing joined
mask pattern and caches one texture per affected area. Original mask files,
field dimensions, source frames, navigation dimensions and ports stay intact.

`forest_freyja_residual_art.gd` reuses the existing Venoa/Tina native bank mesh
and original base/east art at all exact source anchors. Vertical shore depth
fits the unchanged water level to the recovered local bank. It adds no collider.
This is a 3D fit of original 2D art, not a recovered original 3D model.

Physical source blocks are independent:714 West cells become71 exact merged
rectangles,590 East cells become72. Each is a decoder-closed dry/cache100 cell;
none covers an audited source-open point or source port. They reuse Sokia's
existing hidden static-block convention. This prevents recovering visible ground
from inventing a walkable route through blocked originals. Recorded ground100
remains blocked cache void under the existing cliff/background owner, not new
grass; source0 remains untouched. Other native tree/cliff stations are listed
for required owner/appearance reconciliation, not silently treated as restored.

The existing adjoining-city shader receives a default-off prepared exception.
For these audited cells only, it removes adapted alpha-zero city fill/water
while allowing the original exterior, avoiding doubled triangles. Opaque city
pixels and all other maps keep their old ownership. Ground setup explicitly
clears the enable flag, texture and bounds before each map; city setup enables
it only for West/East, on both land and water layers.

The existing Goemon `ENEMY_EDGE=220` restriction remains. It is an adaptation,
not source-confirmed safety: source encounter1000/1006/1008 overlap this area
and remain a separate required encounter reconciliation. The five isolated
water/flower cells at source20–24,7 require no new land or navigation; their
off-route flower presentation is owned by the separate Venoa scenery recovery.

The focused fixture is
`Play Goemon.command --script res://tests/forest-shrine/freyja_residual_surface_test.gd`.
It requires its saved before fields/camera evidence under canonical
`build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Freyja union audit/Residual alpha audit/`.
Use `-- --freyja-gap-before` only against the preserved baseline source, not
to overwrite the before evidence after applying the repair. Fixed normal-camera
images, source crops, technical results and visual qualifications live there.
Headless Dummy MultiMesh reads do not establish rendered station transforms.
Restored collision can shorten the normal camera probe. Those actual normal
views are retained separately; old recorded eyes are explicitly labelled
controlled comparisons, alongside a normally reachable facing-coast angle.
The existing spiky East cliff obstruction remains a required geometry followup.
Passing mask/native checks does not certify that scenery as source-faithful.
This package is explicitly based on the client cache. Newly recovered server
LS2MAP variants remain a separate source reconciliation; client0 is not proof
that the original server area was empty.
