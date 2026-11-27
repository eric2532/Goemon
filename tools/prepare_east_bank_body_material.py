"""Private clean natural bank-body tile; canonical Caps assets remain untouched."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'build/Other Files/Asset Toolkit/East Gate Region/Bank Caps/Body Material Candidate'


def main():
    current = ROOT/'assets/maps/falan/east_region/bank_caps/surfaces.png'
    natural = ROOT/'assets/textures/edo/rock.png'
    before = Image.open(current).convert('RGBA'); rock = Image.open(natural).convert('RGBA')
    assert before.size == (256, 128) and rock.size == (128, 128) and rock.getchannel('A').getextrema() == (255, 255)
    candidate = before.copy(); candidate.paste(rock, (128, 0))
    assert candidate.crop((0, 0, 128, 128)).tobytes() == before.crop((0, 0, 128, 128)).tobytes()
    assert candidate.crop((128, 0, 256, 128)).tobytes() == rock.tobytes()
    OUT.mkdir(parents=True, exist_ok=True); (OUT/'.gdignore').touch(); candidate.save(OUT/'surfaces.png', optimize=True)
    contact = Image.new('RGBA', (768, 300), '#26313a'); draw = ImageDraw.Draw(contact)
    for i, (title, image) in enumerate([('Current architecture motif - rejected', before.crop((128, 0, 256, 128))), ('Existing Edo natural rock/soil', rock), ('Native grass - unchanged', before.crop((0, 0, 128, 128)))]):
        contact.alpha_composite(image.resize((256, 256), Image.Resampling.NEAREST), (i*256, 35)); draw.text((i*256+5, 7), title, fill='white')
    contact.convert('RGB').save(OUT/'material-sources.jpg', quality=95)
    data = {'scope': 'Private material-only replacement. Canonical Caps/front PNGs/source footprints/closed body/support unchanged.',
            'source_paths': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [current, natural]},
            'candidate_png_sha256': hashlib.sha256((OUT/'surfaces.png').read_bytes()).hexdigest(),
            'grass_rgba_sha256': hashlib.sha256(before.crop((0, 0, 128, 128)).tobytes()).hexdigest(),
            'body_rgba_sha256': hashlib.sha256(rock.tobytes()).hexdigest(), 'fixed_world_pitch': 1.2,
            'reuse': 'Existing128px Edo natural-rock tile, also used by the shared StoneFort/cliff material; no architecture window/arch/rail crop.',
            'inferred': 'Unobserved4m bank continuation uses natural brown soil/rock shading. It is reconstructed, not original recovered bank-face paint.',
            'pending': 'Source/reverse gallery and actual same-component bank pair. Material correction alone does not accept hidden body geometry.'}
    (OUT/'source-contract.json').write_text(json.dumps(data, indent=2)+'\n')
    print('Prepared private natural bank-body material; native grass/canonical assets untouched.')


if __name__ == '__main__': main()
