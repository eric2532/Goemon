# Cross Gate ivory/slate menu

`panel.svg` embeds the unchanged recovered `joy:123` system-menu frame from
`Magic Power/research/menu-recovery-20261030/recovered/pieces/joy-123.png`.
The SVG supplies a 62% opaque slate interior behind its transparency and covers the baked
Chinese heading with ivory so each current menu can use its own English labels.
The source client and recovered PNG are unchanged. Source PNG SHA-256:
`a8205d877d66731379f73af18675b40aaa2157c7faa42971702050b47b566e15`.

`button.svg` reuses the existing shared button geometry with an ivory palette.
`compact.svg` reuses the existing thin HUD frame geometry with slate/ivory colors.
`preparation_skin.gd` owns nine-slice margins and interaction colors. Large menus
and upgrade cards use the recovered frame; HUD, toolbars and character cards use
the matching compact frame so borders do not overlap their content.
No client archive or recovery workbench is loaded at runtime.

Slate panel interiors and HUD backgrounds are translucent so the world stays visible.
Recovered frame art, text and portraits retain their original opacity; shared ivory
button backgrounds use 88% opacity without fading their labels or icons.
