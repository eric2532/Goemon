"""Exercise launcher concurrency against real Godot in an isolated tiny project."""
from pathlib import Path
import tempfile,subprocess,time,os
repo=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="goemon-launcher-test-") as folder:
 root=Path(folder);(root/"tools").mkdir();(root/"scenes").mkdir();(root/"logs").mkdir()
 (root/"logs/.gdignore").touch()
 source=(repo/"tools/launch_goemon.command").read_text()
 source=source.replace("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Godot Iteration",str(root/"logs"))
 launcher=root/"tools/launch_goemon.command";launcher.write_text(source)
 (root/"tools/goemon_import_cache.py").write_text((repo/"tools/goemon_import_cache.py").read_text())
 (root/"project.godot").write_text('config_version=5\n[application]\nconfig/name="GoemonLauncherTest"\n')
 (root/"scenes/forest_title.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n')
 (root/"probe.gd").write_text('extends Node\nfunc _ready():\n FileAccess.open("res://logs/started-%d"%OS.get_process_id(),FileAccess.WRITE).store_string("started")\n')
 processes=[]
 try:
  for i in range(2):
   out=(root/'logs'/('launch%d.log'%i)).open('w')
   p=subprocess.Popen(['/bin/zsh',str(launcher),'--headless','--max-fps','60','--quit-after','1200'],stdout=out,stderr=subprocess.STDOUT);processes.append((p,out))
  deadline=time.monotonic()+12
  while time.monotonic()<deadline:
   if len(list((root/'logs').glob('started-*')))>=2:break
   if len(list((root/'logs').glob('started-*')))==1 and any(p.poll() is not None for p,_ in processes):break
   time.sleep(.05)
  starts=len(list((root/'logs').glob('started-*')))
  assert starts==1, f'Expected one game for two concurrent launcher clicks; got {starts}'
  assert sum(p.poll() is None for p,_ in processes)==1,'Duplicate launcher should exit without leaving another process'
 finally:
  for p,out in processes:
   if p.poll() is None:p.terminate()
   p.wait(timeout=10);out.close()
 # The kernel must release the lock after game shutdown, including SIGTERM.
 with (root/'logs/relaunch.log').open('w') as out:
  subprocess.run(['/bin/zsh',str(launcher),'--headless','--quit-after','5'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=30)
 assert len(list((root/'logs').glob('started-*')))==2,'A fresh click must work after the previous game exits'
 assert 'Goemon assets are up to date.' in (root/'logs/relaunch.log').read_text(),'An unchanged launch must skip the importer'
 # New global classes must still be imported before their caller is parsed.
 (root/'new_class.gd').write_text('class_name LauncherFreshClass\nextends RefCounted\n')
 (root/'probe.gd').write_text((root/'probe.gd').read_text()+' assert(LauncherFreshClass.new()!=null)\n')
 with (root/'logs/changed.log').open('w') as out:
  subprocess.run(['/bin/zsh',str(launcher),'--headless','--quit-after','5'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=30)
 assert 'Refreshing changed Goemon assets...' in (root/'logs/changed.log').read_text(),'Changed sources must refresh imports'
 assert 'SCRIPT ERROR' not in (root/'logs/changed.log').read_text(),'New classes must be available to gameplay'
 (root/'study.gd').write_text('extends SceneTree\nfunc _initialize():\n call_deferred("mark_started")\nfunc mark_started():\n assert(current_scene==null,"An asset study must not also start gameplay")\n FileAccess.open("res://logs/study-started",FileAccess.WRITE).store_string("started")\n')
 with (root/'logs/study.log').open('w') as out:
  study=subprocess.Popen(['/bin/zsh',str(launcher),'--headless','--max-fps','60','--quit-after','1800','--script','res://study.gd'],stdout=out,stderr=subprocess.STDOUT)
  try:
   deadline=time.monotonic()+12
   while not (root/'logs/study-started').exists() and study.poll() is None and time.monotonic()<deadline:
    time.sleep(.05)
   assert (root/'logs/study-started').exists(),'The launcher must support standalone asset studies'
   assert len(list((root/'logs').glob('started-*')))==3,'The study must not also start the normal game'
   with (root/'logs/play-during-study.log').open('w') as game_out:
    subprocess.run(['/bin/zsh',str(launcher),'--headless','--quit-after','5'],stdout=game_out,stderr=subprocess.STDOUT,check=True,timeout=20)
   assert study.poll() is None,'The study should still be running'
   assert len(list((root/'logs').glob('started-*')))==4,'A running study must not block the game'
  finally:
   if study.poll() is None:study.terminate()
   study.wait(timeout=10)
 print('GOEMON_LAUNCHER_TEST checks=10 failures=0')
