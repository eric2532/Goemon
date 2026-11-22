"""Compose an editable blink icon around the unchanged original Killer bee art."""
import base64
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/crossgate/bees/portraits.png"
OUTPUT = ROOT / "assets/ui/crossgate/skills/bee-blink-flurry.svg"


def main():
    original = SOURCE.read_bytes()
    assert original[:8] == b"\x89PNG\r\n\x1a\n"
    width, height = struct.unpack_from(">II", original, 16)
    assert width >= 96 and height >= 96
    encoded = base64.b64encode(original).decode("ascii")
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="128" height="128" viewBox="0 0 128 128">
  <defs><clipPath id="bee-crop"><rect width="96" height="64"/></clipPath><g id="bee" clip-path="url(#bee-crop)"><image width="{width}" height="{height}" xlink:href="data:image/png;base64,{encoded}"/></g></defs>
  <path d="M5 85h25M11 99h20M17 111h15" stroke="#83e5ed" stroke-width="4" stroke-linecap="round" opacity=".75"/>
  <use xlink:href="#bee" transform="translate(-12 48) scale(.78)" opacity=".58"/>
  <use xlink:href="#bee" transform="translate(1 19) scale(.75)" opacity=".68"/>
  <use xlink:href="#bee" transform="translate(69 45) scale(.7)" opacity=".65"/>
  <use xlink:href="#bee" transform="translate(34 77) scale(.77)" opacity=".78"/>
  <use xlink:href="#bee" transform="translate(32 4)"/>
  <path d="m111 84 3 7 7 3-7 3-3 7-3-7-7-3 7-3Z" fill="#ddffff"/>
</svg>
'''
    assert len(ET.fromstring(svg).findall("{http://www.w3.org/2000/svg}use")) == 5
    assert base64.b64decode(encoded) == original
    OUTPUT.write_text(svg)


if __name__ == "__main__":
    main()
