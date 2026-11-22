"""Trace Blue CG's published mountain map and place the documented farm landmarks."""
from PIL import Image, ImageDraw, ImageFilter

ROAD, FARM, STOREHOUSE = 911501, 911502, 911503
LAND = {
    ROAD: ("tomato_road", "Northern Mountain Path · 北方的山道", (150, 110)),
    FARM: ("tomato_farm", "Mountain Tomato Farm · 蕃茄種植場", (60, 60)),
}
STORE_SIZE = (24, 20)
BEDS = [(20,34,29,44),(33,36,42,44),(42,24,49,29)]
# https://www.ibluecg.com/task/?id=1-65
# Screen coordinates on the guide's 831×409 Day 5 image. The marked Plateosaur
# square anchors the inverse projection at the documented (68,55)–(73,60) patch.
SPINE = [
    (789,207), (739,184), (710,194), (665,211), (615,185), (637,169),
    (610,154), (638,137), (610,123), (480,197), (488,202), (472,212),
    (524,237), (484,260), (442,239), (400,263), (372,247), (341,265),
    (365,280), (354,289), (385,305), (344,324), (273,288), (252,301),
    (243,295), (266,281), (241,267), (270,252), (240,246), (273,233),
    (215,205), (235,193), (317,232), (372,203), (345,193), (423,160),
    (324,114), (282,133), (231,112), (212,123), (247,139), (215,157),
    (180,140), (143,154), (117,146), (94,160), (108,175), (104,184),
    (126,195), (105,210), (63,191), (43,199), (24,193),
]
BRANCHES = [
    [(710,194), (698,180), (717,169), (732,178)],
    [(540,160), (567,174), (534,191), (510,179)],
    [(524,237), (548,222), (560,233)],
    [(235,193), (268,175), (282,182)],
    [(372,203), (406,219)],
    [(324,114), (341,98), (298,77), (288,83), (320,101)],
    [(344,324), (321,312)],
    [(484,260), (495,248)],
    [(610,204), (588,213), (610,229), (568,248), (590,260), (539,285),
     (518,274), (478,294), (425,286), (404,293), (491,332), (443,353),
     (406,337), (321,379), (345,389), (367,377), (414,395),
     (565,318), (552,308), (578,296)],
]


def mountain_cell(point):
    u, v = point
    dx, dz = (u - 263) / 5.35, (v - 177) / 2.65
    return round(70.5 + (dz + dx) / 2), round(57.5 + (dz - dx) / 2)


ROAD_START, ROAD_END = map(mountain_cell, (SPINE[0], SPINE[-1]))
FARM_START = (50, 49)
WELL = (25, 26)
STORE_DOORS = ((30, 32), (34, 32))
STORE_ARRIVALS = ((9, 17), (13, 17))
LINKS = [
    (1155, 6, 1, ROAD, *ROAD_START), (ROAD, *ROAD_START, 1155, 6, 2),
    (ROAD, *ROAD_END, FARM, *FARM_START), (FARM, *FARM_START, ROAD, *ROAD_END),
    *(row for door, inside in zip(STORE_DOORS, STORE_ARRIVALS)
      for row in ((FARM, *door, STOREHOUSE, *inside), (STOREHOUSE, *inside, FARM, *door))),
]


def local(ident, x, z):
    w, h = STORE_SIZE if ident == STOREHOUSE else LAND[ident][2]
    return (x - w // 2) * 3, (z - h // 2) * 3


def storehouse():
    # shortcut: The guide locates the desk and keeper. Replace the shell when the room cache is available.
    w, h = STORE_SIZE
    floors, objects = [0] * (w * h), [0] * (w * h)
    for z in range(2, 18):
        for x in range(3, 21):
            i = z * w + x
            floors[i] = 3027 if x % 3 else 3028
            if z == 2 or x in (3, 20) or (z == 17 and x not in (9, 13)):
                objects[i] = 16747
    for x, z, serial in [(10,5,17539),(5,6,10500),(18,6,10500),(5,11,10018),
                          (18,10,10018),(5,14,10531),(18,14,10531)]:
        objects[z * w + x] = serial
    return w, h, floors, objects, None


def build_land(output):
    rows, props = [], []
    for ident, (area, title, size) in LAND.items():
        footprint = Image.new("L", size)
        track = Image.new("L", size)
        beds = Image.new("L", size)
        draw, dirt = ImageDraw.Draw(footprint), ImageDraw.Draw(track)
        placed = []
        if ident == ROAD:
            for pixels in [SPINE, *BRANCHES]:
                points = [mountain_cell(p) for p in pixels]
                draw.line(points, fill=255, width=7, joint="curve")
                dirt.line(points, fill=220, width=3, joint="curve")
                for x, z in points:
                    draw.ellipse((x-3,z-3,x+3,z+3), fill=255)
            for x, z in map(mountain_cell, [(740,183),(522,174),(477,213),(270,257),(305,85),(403,155),(118,171)]):
                draw.ellipse((x-5,z-5,x+5,z+5), fill=255)
            start, end = ROAD_START, ROAD_END
        else:
            # shortcut: Preserve the guide's exact landmark cells. The perimeter and crop beds are inferred.
            draw.polygon([(11,13),(27,11),(42,14),(49,22),(53,31),(55,49),(51,53),
                          (42,50),(29,52),(14,49),(8,39),(8,25)], fill=255)
            dirt.line([FARM_START,(46,44),(42,33),(34,32),(27,32),WELL,(19,22)], fill=220, width=5)
            for x0,z0,x1,z1 in BEDS:
                dirt.rectangle((x0,z0,x1,z1), fill=255)
                ImageDraw.Draw(beds).rectangle((x0,z0,x1,z1), fill=255)
            placed.append(("ghana_well", *local(ident,*WELL), .95, 0))
            start, end = FARM_START, WELL
        # The reconstructed spine must connect on the same cardinal grid the game uses.
        reached, queue = {start}, [start]
        for x, z in queue:
            for p in [(x+1,z),(x-1,z),(x,z+1),(x,z-1)]:
                if p not in reached and 0<=p[0]<size[0] and 0<=p[1]<size[1] and footprint.getpixel(p):
                    reached.add(p)
                    queue.append(p)
        assert end in reached
        for x,z in reached:
            if track.getpixel((x,z)) or (x*17+z*23)%19 or (x-start[0])**2+(z-start[1])**2<25:
                continue
            if ident==FARM and (18<=x<=50 and 22<=z<=46 or (x-25)**2+(z-26)**2<25):
                continue
            placed.append(("pine" if (x+z)%4 else "moss_rock", *local(ident,x,z), .72, (x*13+z*41)%360))
        track = track.filter(ImageFilter.GaussianBlur(.38))
        surface = Image.merge("RGBA", (footprint.point(lambda x: 255-x), track,
                                        beds, Image.new("L", size, 255)))
        name = f"{area}_surface.png"
        surface.save(output / name, optimize=True)
        ox, oz = local(ident,0,0)
        sx, sz = local(ident,*start)
        rows.append(f' "{area}":[{ident},"{title}",Vector2({ox},{oz}),preload("res://assets/maps/falan/{name}"),Vector2({sx},{sz})],')
        entries = ",".join(f'["{kind}",Vector2({x},{z}),{scale},{yaw}]' for kind,x,z,scale,yaw in sorted(placed))
        props.append(f' "{area}":[{entries}],')
    return rows, props
