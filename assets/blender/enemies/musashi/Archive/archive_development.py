from pathlib import Path
import hashlib,json,zipfile,shutil
root=Path(__file__).resolve().parent.parent
validation=json.loads((root/'Final/Validation/final_validation.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(root/'Final/Musashi_Final.blend')==validation['final_sha256']
assert validation['missing_dependencies']==0 and all(i['packed'] and i['external_exists'] for i in validation['file_images'])
appearance=json.loads((root/'Final/Validation/cleanup_appearance_check.json').read_text());assert appearance['visible_appearance_preserved']
backup=json.loads((root/'Final/Validation/backup_manifest.json').read_text());assert sha(root/'Archive/Musashi_Development_Backup.blend')==backup['sha256']
dirs=sorted([p for p in root.glob('Phase 1 *') if p.is_dir()])+[root/'Sprite']
keep_tools={'asset_validation.py','verify_final.py','assemble_final_review.py','check_lighting.py'}
extra_tools=[p for p in (root/'Final/Tools').iterdir() if p.is_file() and p.name not in keep_tools]
intermediates=list((root/'Final/Validation').glob('Final_PreCleanup.blend*'))
files=[]
for folder in dirs:
 assert folder.parent==root
 files.extend(p for p in folder.rglob('*') if p.is_file())
files+=extra_tools+intermediates+[root/'README.md',root/'AGENTS.md']
files=sorted(set(files));manifest=[{'path':str(p.relative_to(root)),'size':p.stat().st_size,'sha256':sha(p)} for p in files]
archive=root/'Archive/Musashi_Visual_Development.zip';temp=archive.with_suffix('.zip.tmp');assert not archive.exists(),'Do not overwrite a previous archive'
with zipfile.ZipFile(temp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in files:z.write(p,str(p.relative_to(root)))
 z.writestr('ARCHIVE_MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(temp) as z:
 assert z.testzip() is None
 for entry in manifest:assert hashlib.sha256(z.read(entry['path'])).hexdigest()==entry['sha256'],entry['path']
temp.rename(archive)
record={'archive':str(archive.relative_to(root)),'archive_sha256':sha(archive),'verified_file_count':len(manifest),'original_total_bytes':sum(e['size'] for e in manifest),'archive_bytes':archive.stat().st_size,'archived_development_folders':[p.name for p in dirs if p.name!='Sprite'],'reference_moved_to':'Final/Reference/Musashi_Original_Reference.png','verification':'ZIP CRC plus SHA-256 of every archived file, completed before removing active development folders.','files':manifest}
(root/'Archive/development_archive_manifest.json').write_text(json.dumps(record,indent=2))
# Only now remove the verified archived copies from the active asset folder.
for folder in dirs:shutil.rmtree(folder)
for p in extra_tools+intermediates:p.unlink()
assert sha(root/'Final/Musashi_Final.blend')==validation['final_sha256']
assert sha(root/'Archive/Musashi_Development_Backup.blend')==backup['sha256']
print(json.dumps({k:v for k,v in record.items() if k!='files'},indent=2))
