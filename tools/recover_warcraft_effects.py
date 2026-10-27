"""Prepare recovered spell textures/emitters and native billboard flags read-only."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'Warcraft'
OUT = ROOT / 'assets/characters/warcraft/effects'
OUT.mkdir(parents=True, exist_ok=True)
report = {'sources': {}, 'emitters': {}, 'billboards': {}, 'upright': {}}
for character, package, model in [(31, 'Blademaster', 'HeroBladeMaster'), (32, 'Illidan', 'IllidanEvil')]:
    source = SOURCE / 'work' / (model + '.mdx.json')
    data = json.loads(source.read_text())
    report['sources'][str(source)] = hashlib.sha256(source.read_bytes()).hexdigest()
    report['upright'][str(character)] = [n['Name'] for n in data['Nodes'] if n['Flags'] & 64 and not n['Flags'] & 8]
    report['billboards'][str(character)] = [n['Name'] for n in data['Nodes'] if n['Flags'] & (8 | 64)]
for key, package, model, index in [('immolation', 'DemonHunter', 'ImmolationTarget', 0), ('spin', 'Blademaster', 'HeroBladeMaster', 1), ('slam', 'Blademaster', 'HeroBladeMaster', 0)]:
    source = SOURCE / 'work' / (model + '.mdx.json')
    data = json.loads(source.read_text())
    emitter = data['ParticleEmitters2'][index].copy()
    path = SOURCE / 'assets' / package / 'original' / data['Textures'][emitter['TextureID']]['Image'].replace('\\', '/')
    path = path.with_suffix('.png')
    shutil.copy2(path, OUT / path.name)
    emitter['texture'] = path.name
    report['emitters'][key] = emitter
    for path in [source, path]:
        report['sources'][str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
for package, filename in [('Blademaster','Green_Glow2.png'),('DemonHunter','Green_Glow3.png')]:
    path = SOURCE / 'assets' / package / 'original/Textures' / filename
    shutil.copy2(path, OUT / filename)
    report['sources'][str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
(OUT / 'sources.json').write_text(json.dumps(report, indent=2) + '\n')
assert len(report['billboards']['32']) == 76
print('Recovered 3 original emitters and billboard flags:', {k:len(v) for k,v in report['billboards'].items()})
