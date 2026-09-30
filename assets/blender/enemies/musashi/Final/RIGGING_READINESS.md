# Rigging readiness — inspection only

`MUSASHI_FINAL_APPROVED` is the locked visual master for the next phase. No armature, skin weights, animation, export or Godot import has been created. It is ready for rig planning; deformation has not been approved or tested with a rig.

## Findings to address in a separate rigging copy

| Area | Finding / next-phase consideration |
| --- | --- |
| Shoulders / elbows | Each sleeve is a separate 112-vertex loft, meeting the jacket through layered overlap. There are no dedicated anatomical shoulder/elbow deformation loops. Test arm raises and bends; agree on any required topology changes before editing the locked master. |
| Wrists / hands | Simplified hand meshes sit inside the cuffs. Existing contact is intentional. Coordinate sleeve/cuff/hand weights or rigid attachments so bending does not reveal gaps or create excessive intersections. |
| Hips / knees | The continuous baggy pants mesh uses irregular, mostly triangulated sculpt topology. It has no dedicated knee loop layout. Test crouching and stepping for crotch collapse, knee pinching and loss of upper-pants volume. Do not retopologize the approved master automatically. |
| Ankles / wraps / shoes | Wrap bases, individual overlap ridges and shoe pieces remain separate. Most ridges are open-ended decorative tubes. Bind them consistently to the lower legs/feet; do not weld or cap them just for cleanliness. |
| Neck / face | The head and neck overlap as designed. Facial features are separate thin graphic surfaces, including intentionally open boundaries. Attach them to the head consistently; facial-expression deformation needs a separate design decision. |
| Hair / ears | Main hair, local side hair, head and ear intentionally intersect. Rigid head attachment is appropriate for the existing design; no dynamic hair system has been made. Twelve isolated microscopic zero-volume duplicate triangle pairs were the sole technical topology cleanup. |
| Jacket / vest / print | Jacket, lapel, collar, vest, closures and flame patches are layered meshes. Weight transfer and deformation tests are needed to keep the print on the sleeves and preserve overlaps. |
| Material portability | Painted shapes use a `MUSASHI_PaintRest` point attribute, so their coordinates are stored on the approved rest surface rather than derived from studio lights. Blender shaders and AO nodes still require a bake or an explicit game-shader translation during integration. Existing UV maps are partial and not a validated game atlas. |
| Budget | The locked master has 86 character meshes, 46,177 vertices and 90,160 triangles. No LOD, merge, decimation or destructive optimization was performed. Evaluate the target engine budget in the integration phase. |

## Technical results

- All character object transforms are identity; existing common assembly origins were preserved.
- All remaining vertex positions, face winding, smoothing and material assignments were preserved, except removal of 12 isolated, zero-volume hair scraps (24 faces / 36 vertices).
- No degenerate faces, duplicate faces, loose vertices, or inconsistent manifold-edge winding remain.
- The main closed body, hair, hands and garment masses are manifold. Open boundaries in 51 decorative/surface meshes are retained deliberately; a universal “make manifold” operation would alter the approved design.
- No unapplied modifiers remain, so none were automatically applied or removed from character geometry.
- Reference image is packed; the external reference is also supplied. No linked libraries or missing required dependencies.

All approved design geometry stays locked. Reported concerns are for the explicitly requested next phase, not authorization to redesign this asset.
