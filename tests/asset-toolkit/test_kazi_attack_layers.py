import sys
from pathlib import Path
import unittest

from PIL import Image,ImageDraw

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools'))
from prepare_crossgate_kazi_attack import outer_effect


class OriginalKaziLayers(unittest.TestCase):
    def test_protected_character_and_blade_stay_while_outer_explosion_can_move(self):
        image=Image.new('RGBA',(80,80));draw=ImageDraw.Draw(image)
        draw.rectangle((30,20,45,70),fill=(30,30,30,255))
        draw.rectangle((35,30,40,40),fill=(200,20,255,255))
        draw.line((42,45,75,28),fill=(45,45,45,255),width=2)
        draw.rectangle((55,35,74,54),fill=(200,20,255,255))
        draw.rectangle((60,40,68,48),fill=(255,255,255,255))
        original=image.tobytes();effect=outer_effect(image,(28,18,48,72))
        self.assertEqual(image.tobytes(),original)
        self.assertEqual(effect.getpixel((37,35))[3],0)
        self.assertEqual(effect.getpixel((70,31))[3],0)
        self.assertEqual(effect.getpixel((65,45)),(255,255,255,255))
        self.assertEqual(effect.getpixel((70,50)),image.getpixel((70,50)))


if __name__=='__main__':unittest.main()
