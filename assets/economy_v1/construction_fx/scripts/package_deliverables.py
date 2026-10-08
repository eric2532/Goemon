from pathlib import Path
import json,hashlib,zipfile
p=Path(__file__).resolve().parent.parent
m=json.loads((p/'asset_manifest.json').read_text());m['qa']={'blender_roundtrip':'PASS','blender_version':'4.3.2','godot_asset_import_hammer_and_completion_playback':'PASS','godot_version':'4.6.3','gameplay_integration':'NOT PERFORMED'}
for x in m['files']:
 f=p/'exports'/x['file'];x['bytes']=f.stat().st_size;x['sha256']=hashlib.sha256(f.read_bytes()).hexdigest()
(p/'asset_manifest.json').write_text(json.dumps(m,indent=2))
files=[p/'FireSiege_ConstructionFX_v1.blend',p/'README.md',p/'IMPLEMENTATION_NOTES.md',p/'asset_manifest.json']
files+=sorted((p/'exports').glob('*.glb'))
files+=sorted((p/'previews').glob('demo_*.png'))
files+=[p/'previews/FS_ConstructionFX_ContactSheet.png',p/'previews/FS_ConstructionFX_Preview.mp4']
files+=sorted((p/'scripts').glob('*.py'))
files+=[p/'qa/roundtrip_report.json',p/'qa/godot_import_report.json',p/'qa/video_report.json',p/'qa/godot_import/check_assets.gd',p/'qa/godot_import/project.godot']
for f in files:assert f.exists() and f.stat().st_size<20*1024*1024,f
checks='\n'.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+str(f.relative_to(p)) for f in files)+'\n'
(p/'CHECKSUMS.sha256').write_text(checks);files.append(p/'CHECKSUMS.sha256')
with zipfile.ZipFile(p/'FireSiege_ConstructionFX_v1.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for f in files:z.write(f,Path('FireSiege_ConstructionFX_v1')/f.relative_to(p))
with zipfile.ZipFile(p/'FireSiege_ConstructionFX_v1.zip') as z:assert z.testzip() is None
print('Verified package:',p/'FireSiege_ConstructionFX_v1.zip', (p/'FireSiege_ConstructionFX_v1.zip').stat().st_size,'bytes;',len(files),'files')
