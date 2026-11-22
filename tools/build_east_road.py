"""Join the existing East Gate and Il road masks in the East Gate coordinate frame."""
from pathlib import Path
from PIL import Image


def build(output):
    gate=Image.open(output/'east_approach_surface.png').convert('RGBA')
    coast=Image.open(output/'east_coast_surface.png').convert('RGBA')
    joined=Image.new('RGBA',(386,459))
    joined.paste(gate,(65,0))
    for y in range(coast.height):
        for x in range(coast.width):
            at=(320-y,138+x)
            pixel=coast.getpixel((x,y))
            if pixel[3] and (210+x*3>=411 or not joined.getpixel(at)[3]):
                joined.putpixel(at,pixel)
    joined.save(output/'east_road_surface.png',optimize=True)
    print('Joined East Gate and Il countryside: 386 × 459 source-grid points.')


if __name__=='__main__':
    build(Path(__file__).resolve().parents[1]/'assets/maps/falan')
