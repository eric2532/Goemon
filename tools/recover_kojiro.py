"""Recover Kojiro from the supplied USA duel overlay, retaining source provenance."""
import argparse
import hashlib
import json
import struct
import shutil
from pathlib import Path
from recover_vambee_wolf import assemble, streams, BASE, RECOVERY
from recover_monster_audio import recover as audio
from recover_skullpion_effects import load_vram, texture, png
from recover_skullpion import recover as geometry

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/recovered_kojiro'
WORK=ROOT/'build/Other Files/Asset Toolkit/Kojiro'
SOURCE='raw/SC03.CD.dir/FILE_014.dir/0.4.dec'
AUDIO_BANK='raw/SC03.CD.dir/FILE_017.dir/0.2'
# 8018638C selects table 801904F0: slot 3 strides in Z; slots 6/7 stride in X.
SEMANTICS=dict(idle=0,walk=1,run=2,strafe_left=3,strafe_right=4,run_right=5,
              run_left=6,jump=7,fall=8,air=9,air_cut=10,air_spin=11,
              hurt=12,ready=13,wind=14,slash=15,homing=16,cinematic=17)
SOUNDS={0xa35:'homing_release',0xa36:'wave_release',0xa37:'wind_release',
        0xa7e:'homing_voice',0xa7f:'air_cut_voice',0xa80:'air_spin_voice',
        0xa81:'wave_voice',0xa82:'wind_voice',0xa83:'unused_voice_a83',
        0xa84:'unused_voice_a84',0xa85:'hurt_1',0xa86:'hurt_2',0xa87:'defeat',
        0x437:'contact',0x438:'contact_strong',0x439:'contact_heavy',0x43c:'reaction'}


def recover_audio():
    # 80184868 loads CD table entry 195 (SC03/17) into sound resource 57.
    audio('kojiro','SC03',14,SOUNDS,57,OUT/'audio',WORK/'Audio Catalog',
          ['Scene owner SC03/14; duel audio is separately loaded from SC03/17, not the scenery bank.',
           '80184878 selects resource 57; 801848A8..AC selects 800AEE48 = CD table entry 195 = SC03/17.',
           'A83/A84 are disabled source events retained for inspection. A88/A89 are disabled and refer to absent tones; no original sword sample is claimed.'],
          bank_sources={57:AUDIO_BANK})


def recover():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    data=(RECOVERY/SOURCE).read_bytes()
    assert b'Kojiro, you....!' in data
    assert struct.unpack_from('<I',data,0x80190494-BASE)[0]==0x801d6d6c
    clips=streams(data,0x801e2170,0x801e2f68)
    assert len(clips)==18 and [c['ticks'] for c in clips[14:17]]==[71,50,30]
    semantics={key:clips[index]['name'] for key,index in SEMANTICS.items()}
    # The cutscene enters these continuations directly, inside the final stream.
    for start in (0x801e2ea0,0x801e2ee8):clips+=streams(data,start,0x801e2f68)
    frame=dict(tick=0,hold=0,pose='0x801903f0',tagged_pointer='0x811903f0',
               command_address='0x80190468',packed=True)
    clips.append(dict(name='Source__80190468',address='0x80190468',ticks=1,frames=[frame],
                      terminal='external_hold',stream_sha256=hashlib.sha256(data[0x80190468-BASE:0x80190470-BASE]).hexdigest()))
    semantics['death']='Source__80190468'
    assemble(SOURCE,'kojiro',0x801d6d2c,15,clips,semantics,output_dir=OUT)
    effects(data)
    recover_audio()
    profile=dict(source=SOURCE,sha256=hashlib.sha256(data).hexdigest(),fps=30,semantics=semantics,
        source_part_list='0x801d6d2c',body_list='0x801d6d6c',blade_part=14,
        blade_endpoints=[[0,0,0],[0,0,-64]],
        contacts={'slash':[[0,0,0],[0,-48,-40],[-24,-48,-36],[24,-48,-36]],
                  'air_spin':[[0,0,0],[0,-64,-36],[0,-48,-36],[0,-32,-36]]},
        actions={
            'slash':dict(clip=semantics['slash'],ticks=50,contacts=[15],damage=24,source_handler='0x80187300'),
            'air_cut':dict(clip=semantics['air_cut'],ticks=20,contacts=[15],damage=24,voice='air_cut_voice',source_handler='0x801874c0'),
            'air_spin':dict(clip=semantics['air_spin'],ticks=24,contacts=[15],damage=24,voice='air_spin_voice',source_handler='0x801874c0'),
            'homing':dict(clip=semantics['homing'],ticks=30,releases=[15],voice='homing_voice',sound='homing_release',source_handler='0x801863b8',spread=[-512,0,512],speed_units_per_tick=24,lifetime_ticks=90),
            'wave':dict(clip=semantics['slash'],ticks=50,releases=[15],voice='wave_voice',sound='wave_release',source_handler='0x80186a74',speed_units_per_tick=16,lifetime_ticks=90),
            'wind':dict(clip=semantics['wind'],ticks=71,releases=[40,42,44,46],voice='wind_voice',sound='wind_release',source_handler='0x80187090',scales=[1,.75,.5,.25],speed_units_per_tick=16,lifetime_ticks=90)},
        adaptation=['Player movement, jumps, damage progression, collision and cooldowns use Goemon shared controllers.',
                    'Original enemy windup/AI and arena hostage choreography are not a second gameplay simulation.',
                    'Every numeric duel clip plus directly referenced continuations and defeat pose remain editable.',
                    'Complete local sound bank retained; scene dialogue streaming is separate from combat event voices.'])
    (OUT/'combat.json').write_text(json.dumps(profile,indent=2)+'\n')


def effects(data):
    out=OUT/'effects';out.mkdir(parents=True,exist_ok=True)
    pac=(RECOVERY/'raw/SC03.CD.dir/FILE_014').read_bytes();vram,present=load_vram(pac)
    report=dict(source=SOURCE,source_sha256=hashlib.sha256(data).hexdigest(),pac_sha256=hashlib.sha256(pac).hexdigest(),sprites={})
    for name,address,count in [('homing',0x80190590,1),('spark',0x801905e4,1),('wave',0x80190720,8)]:
        frames=[];descriptors=[]
        for i in range(count):
            raw=data[address-BASE+i*12:address-BASE+(i+1)*12]
            encoded,w,h,x,y,dx,dy=struct.unpack('<HBBHHhh',raw)
            row=(encoded>>8)+256;clut=(row<<6)|(0x16 if row<480 else 0x10)
            assert (w+1)%4==0
            frames.append(texture(vram,present,(x,y,(w+1)//4,h+1),clut))
            descriptors.append(dict(raw=raw.hex(),clut=clut,rect=[x,y,w+1,h+1],origin=[dx,dy]))
        png(out/(name+'.png'),w+1,(h+1)*count,b''.join(frames))
        report['sprites'][name]=dict(address=hex(address),frames=count,width=w+1,height=h+1,descriptors=descriptors,
                                      rgba_sha256=hashlib.sha256(b''.join(frames)).hexdigest())
    # Wind alternates two 64x64 indexed RAM images, uploaded to VRAM by 80186F84.
    palette=struct.unpack_from('<16H',data,0x801917e8-BASE)
    frames=[]
    for address in (0x801907e8,0x80190fe8):
        frame=bytearray()
        for byte in data[address-BASE:address-BASE+2048]:
            for index in (byte&15,byte>>4):
                color=palette[index];rgb=[(color>>s)&31 for s in (0,5,10)]
                frame.extend([(c<<3)|(c>>2) for c in rgb]+[0 if color==0 else 255])
        frames.append(frame)
    png(out/'wind.png',64,128,b''.join(frames))
    report['sprites']['wind']=dict(addresses=['0x801907e8','0x80190fe8'],palette_address='0x801917e8',palette=list(palette),frames=2,width=64,height=64,
                                  rgba_sha256=hashlib.sha256(b''.join(frames)).hexdigest())
    geometry(argparse.Namespace(recovery_root=RECOVERY,output=out),[('Wind',0x801c97c8,1)],0,0,'wind',source_file=SOURCE)
    dust_source='raw/MAIN.CD.dir/FILE_010.dir/1.1'
    resident=(RECOVERY/dust_source).read_bytes()
    report['dust']=dict(source=dust_source,source_sha256=hashlib.sha256(resident).hexdigest(),
        caller='0x80186ed4',actor='0x205',handler='0x80144558',sprite='0x800d387c',frames='0x800d3888',
        texture='assets/characters/recovered_musashi/assimilation/rocket_trail.png',
        texture_sha256=hashlib.sha256((ROOT/'assets/characters/recovered_musashi/assimilation/rocket_trail.png').read_bytes()).hexdigest(),
        clut_row=412,frame_ticks=1,frame_count=10,scale=3,emission_ticks=1,side_speed_units_per_tick=16)
    report['trail']=dict(renderer='0x80187ee8',ticks=16,initial_rgb=[240,120,240],decrement=15,blend='additive',blade_part=14)
    report['notes']=['Original textures, palette, origins and source addresses; no replacement particle artwork.',
                     'Godot billboarding, projection, lighting and blending are host-renderer adaptations.']
    (out/'sources.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--audio-only',action='store_true')
    args=parser.parse_args()
    recover_audio() if args.audio_only else recover()
