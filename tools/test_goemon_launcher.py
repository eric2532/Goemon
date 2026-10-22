"""Exercise launcher concurrency against real Godot in an isolated tiny project."""
from pathlib import Path
import tempfile,subprocess,time,os
repo=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="goemon-launcher-test-") as folder:
 root=Path(folder);(root/"tools").mkdir();(root/"scenes").mkdir();(root/"logs").mkdir()
 source=(repo/"tools/launch_goemon.command").read_text()
 source=source.replace("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Godot Iteration",str(root/"logs"))
 launcher=root/"tools/launch_goemon.command";launcher.write_text(source)
 (root/"project.godot").write_text('config_version=5\n[application]\nconfig/name="GoemonLauncherTest"\n')
 (root/"scenes/forest_shrine.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n')
 (root/"probe.gd").write_text('extends Node\nfunc _ready():\n FileAccess.open("res://started-%d"%OS.get_process_id(),FileAccess.WRITE).store_string("started")\n')
 processes=[]
 try:
  for i in range(2):
   out=(root/('launch%d.log'%i)).open('w')
   p=subprocess.Popen(['/bin/zsh',str(launcher),'--headless','--max-fps','60','--quit-after','1200'],stdout=out,stderr=subprocess.STDOUT);processes.append((p,out))
  deadline=time.monotonic()+12
  while time.monotonic()<deadline:
   if len(list(root.glob('started-*')))>=2:break
   if len(list(root.glob('started-*')))==1 and any(p.poll() is not None for p,_ in processes):break
   time.sleep(.05)
  starts=len(list(root.glob('started-*')))
  assert starts==1, f'Expected one game for two concurrent launcher clicks; got {starts}'
  assert sum(p.poll() is None for p,_ in processes)==1,'Duplicate launcher should exit without leaving another process'
 finally:
  for p,out in processes:
   if p.poll() is None:p.terminate()
   p.wait(timeout=10);out.close()
 # The kernel must release the lock after game shutdown, including SIGTERM.
 with (root/'relaunch.log').open('w') as out:
  subprocess.run(['/bin/zsh',str(launcher),'--headless','--quit-after','5'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=30)
 assert len(list(root.glob('started-*')))==2,'A fresh click must work after the previous game exits'
 print('GOEMON_LAUNCHER_TEST checks=3 failures=0')
