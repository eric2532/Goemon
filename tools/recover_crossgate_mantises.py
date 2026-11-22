"""Recover every reviewed mantis record and compose a shared guard-pet sprite bank."""
import argparse
import hashlib
import json
import struct
import sys
import wave
from pathlib import Path
from PIL import Image
from recover_crossgate_hounds import ROOT, TABLE_WIDTH, index_frame, write_atlas

OUT = ROOT / 'assets/characters/crossgate/mantises'
BANK = ROOT / 'assets/characters/crossgate/guard_pets'
HOUNDS = ROOT / 'assets/characters/crossgate/hounds'
SNOW_HOUND_GUARD = BANK / 'snow_hound_guard'
SNOW_HOUND = 'original:2821'
ACTORS = [(101320+i, f'original:{2867+i}') for i in range(5)] + [
    (108165, 'joy-ex:622'), (108166, 'joy-ex:623'), (108209, 'joy-ex:553'),
    (108443, 'ch1:486'), (109271, 'ch1:688'), (109880, 'puk3:823'),
    (109932, 'puk3:875'), (116563, 'puk3:709'), (117029, 'v3:775'),
    (117137, 'puk3:338')] + [(119195+i, f'ch1:{896+i}') for i in range(5)]
# Archive every source action; the first six match the shared army presentation.
ACTIONS = (0, 3, 5, 8, 10, 1, 2, 6, 9)
COMPANION_CUE_LIMIT = 20
COMPANION_TIMELINE_STRIDE = 2 + COMPANION_CUE_LIMIT * 2

def recover(source, actors=ACTORS, out=OUT, xl_ids=range(119195,119200), profiles=None, legacy_contacts=True):
    sys.path.insert(0, str(source / 'tools'))
    import cg_assets as cg
    import cg_sounds
    if profiles is not None:
        for profile in profiles.values():
            for pack, corrections in profile.get('graphic_dimensions',{}).items():
                existing=cg.graphic_dimensions().setdefault(pack,{})
                assert all(ident not in existing or existing[ident]==row for ident,row in corrections.items())
                existing.update(corrections)
        cg.graphic_data.cache_clear()
    extra_actions = sorted({c['action'] for _, key in actors for c in cg.actor(key)[2]} - set(range(11))) if profiles is not None else []
    actions = ACTIONS + (4, 7) + tuple(extra_actions) if profiles is not None else ACTIONS
    cue_limit = (15 if legacy_contacts else COMPANION_CUE_LIMIT) if profiles is not None else 13
    unique, rows, frames, palettes, variants, timelines = {}, [], [], [], [], []
    sounds = set()
    portraits = Image.new('RGBA', (5*96, ((len(actors)+4)//5)*96))
    for skin, (ident, key) in enumerate(actors):
        if profiles is not None:print('RECOVER',out.name,ident,key,flush=True)
        actor, _, original = cg.actor(key)
        assert actor == ident
        portrait_idle=next(c for c in original if c['action']==0 and c['direction']==4)
        motion_key=profiles[key].get('motion_key',key) if profiles is not None else key
        if motion_key!=key:
            actor, _, original=cg.actor(motion_key)
            assert actor==ident
        clips = {(c['action'], c['direction']): c for c in original}
        assert all(c['action'] in actions for c in original)
        # Keep the chosen archive portrait when its stale motion references need a compatible source.
        image, _, oy = cg.frame_parts(key, portrait_idle['index'], 0)
        bounds = image.getbbox()
        # Match hound pixel density; shadows/aura must not shrink the body.
        resolution = 2 if ident in xl_ids else 1
        pixel_size = .0375/resolution
        ground_shift = 10*(resolution-1)
        if profiles is not None:ground_shift += profiles[key].get('ground_shift',0)
        preview = image.crop(bounds); preview.thumbnail((92, 92), Image.Resampling.NEAREST)
        portraits.paste(preview, (skin%5*96+(96-preview.width)//2, skin//5*96+96-preview.height))
        palette = {(0, 0, 0, 0): 0}
        cached, metadata, attacks = {}, [], []
        for action in actions:
            for direction in range(8):
                clip = clips.get((action, direction))
                if clip is None:
                    assert action not in actions[:6]
                    rows.append((0, 0, 1, pixel_size)); continue
                missing = set(); cues = cg_sounds.clip_cues(clip, missing=missing)
                allowed_missing={265}|set(profiles[key].get('missing_audio',[])) if profiles is not None else set()
                assert not missing-allowed_missing, (ident,key,action,direction,missing)
                sounds.update(c['id'] for c in cues)
                if missing:
                    # Keep verified unavailable sound markers without inventing a sample or changing contact timing.
                    cues += [dict(id=f[3]%10000,frame=i,flag=f[3],atMs=i*clip['duration']/len(clip['frames']),missing_audio=True)
                             for i,f in enumerate(clip['frames']) if f[3]%10000 in missing]
                    cues.sort(key=lambda cue:cue['atMs'])
                if profiles is not None:
                    # 10000 is an original impact marker with no accompanying sound.
                    cues += [dict(id=0,frame=i,flag=10000,atMs=i*clip['duration']/len(clip['frames']),silent=True)
                             for i,f in enumerate(clip['frames']) if f[3]==10000]
                    cues.sort(key=lambda cue:cue['atMs'])
                metadata.append(dict(action=action, direction=direction, source_index=clip['index'],
                                     duration_ms=clip['duration'], frames=len(clip['frames']), sounds=cues))
                if action == 5:
                    if profiles is not None:
                        cues = [dict(cue, contact=cue['flag'] >= 10000 and
                                     (legacy_contacts or cue['flag'] < 20000)) for cue in cues]
                    assert 0 < len(cues) <= cue_limit, (ident,key,len(cues))
                    if profiles is not None:assert any(cue['contact'] for cue in cues),(ident,key,direction)
                    attacks.append(cues)
                    timelines.extend((clip['duration']*.03, len(cues)))
                    for cue in cues:
                        code=cue['id']+(10000 if cue['contact'] else 20000) if profiles is not None else cue['id']
                        timelines.extend((cue['atMs']*.03, code))
                    timelines.extend((0, 0)*(cue_limit-len(cues)))
                rows.append((len(frames), len(clip['frames']), clip['duration']/1000, pixel_size))
                for i, frame in enumerate(clip['frames']):
                    token = (frame[:3], clip['palette'], clip['flags'], clip['high'])
                    if token not in cached:
                        try:image, x, y = cg.frame_parts(motion_key, clip['index'], i)
                        except ValueError as error:
                            detail=f'{ident} {key} action {action} direction {direction} frame {i}: {error}'
                            if profiles is None or action in actions[:6]:raise ValueError(detail) from error
                            metadata[-1]['unavailable']=detail
                            rows[-1]=(len(frames),0,clip['duration']/1000,pixel_size)
                            print('UNAVAILABLE_ARCHIVAL_CLIP',detail,flush=True)
                            break
                        cached[token], palette = index_frame(image, x, y-ground_shift, palette, palettes, unique)
                    frames.append(cached[token])
        palettes.append(list(palette))
        variant=dict(id=ident, key=key, clips=metadata, attack_directions=attacks,
                     fall_duration=max(clips[10,d]['duration'] for d in range(8))/1000)
        if profiles is not None:variant.update(profiles[key])
        variants.append(variant)
    pages = write_atlas(out, unique, palettes, rows, frames, 2048, TABLE_WIDTH,grouped=profiles is not None)
    portraits.save(out/'portraits.png')
    sound_manifest=json.loads((source/'godot/assets/sounds/manifest.json').read_text())['sounds']
    audio=ROOT/'assets/audio/crossgate'/out.name;audio.mkdir(parents=True,exist_ok=True)
    recovered={}
    for sound in sorted(sounds):
        spec=sound_manifest[str(sound)];path=source/'godot/assets'/spec['file']
        with wave.open(str(path),'rb') as stream:
            assert hashlib.sha256(stream.readframes(stream.getnframes())).hexdigest()==spec['pcmSha256']
        dest=audio/path.name;dest.write_bytes(path.read_bytes())
        recovered[str(sound)]=dict(spec,goemon_file=str(dest.relative_to(ROOT)))
    data=dict(variants=variants,pages=pages,actions=actions,table_width=TABLE_WIDTH,
              clip_count=len(rows),frame_count=len(frames),timelines=timelines,sounds=recovered)
    if profiles is not None:data['timeline_stride']=2+cue_limit*2
    (out/'motions.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    if profiles is None:
        recover_snow_hound_guard(cg)
        compose()
    print(f'{len(variants)} {out.name}; {sum(len(v["clips"]) for v in variants)} clips; {len(frames)} frame records; {pages} pages; {len(recovered)} sounds')

def recover_snow_hound_guard(cg):
    _, _, clips = cg.actor(SNOW_HOUND)
    guards = sorted((clip for clip in clips if clip['action'] == 9), key=lambda clip: clip['direction'])
    assert [clip['direction'] for clip in guards] == list(range(8))
    unique, frames, palettes = {}, [], []
    palette = {(0, 0, 0, 0): 0}
    for clip in guards:
        assert len(clip['frames']) == 1
        frame, palette = index_frame(*cg.frame_parts(SNOW_HOUND, clip['index'], 0), palette, palettes, unique)
        frames.append(frame)
    palettes.append(list(palette))
    pages = write_atlas(SNOW_HOUND_GUARD, unique, palettes, [], frames, 2048, TABLE_WIDTH)
    assert pages == 1

def compose():
    """Reference family atlas pages, preserving the stable hound/mantis skin order."""
    folders=[HOUNDS,OUT]
    for name in ['dragon_lizards','bees']:
        folder=OUT.parent/name
        if (folder/'motions.json').exists():folders.append(folder)
    registry=OUT.parent/'companions/catalog.json'
    if registry.exists():
        folders.extend(OUT.parent/'companions'/name for name in json.loads(registry.read_text())['families'])
    clips,frames,variants,timelines,paths,sounds,sources=[],[],[],[],[],{},{}
    palettes=[];palette_offset=0;skin_pages=[];snow_guards={}
    for folder in folders:
        data=json.loads((folder/'motions.json').read_text())
        rows=list(struct.iter_unpack('<4f',(folder/'frames.bin').read_bytes()))
        source_palette=Image.open(folder/'palette.png').convert('RGBA')
        for skin in range(len(data['variants'])):
            used=set()
            actions=data.get('actions',ACTIONS[:6])
            for action in ACTIONS[:6]:
                # Some bosses have a one-frame sprint pose; reuse their authored walking loop in that slot.
                source_action=data['variants'][skin].get('run_action',3) if action==3 else action
                for direction in range(8):
                    row=rows[(skin*len(actions)+actions.index(source_action))*8+direction]
                    if action==8 and row[1]==0:
                        # A source with an empty hurt clip keeps its idle art under the shared hit flash.
                        row=rows[(skin*len(actions)+actions.index(0))*8+direction]
                    assert row[1]>0
                    clips.append((row[0]+len(frames)//2,*row[1:]))
                    for frame in range(int(row[0]),int(row[0]+row[1])):
                        used.add(int(rows[data['clip_count']+frame*2+1][2])+len(paths))
            key=data['variants'][skin]['key']
            if key == 'original:2823':
                guard=[]
                for direction in range(8):
                    start,count,*_=rows[(skin*len(actions)+actions.index(9))*8+direction]
                    assert count==1
                    frame=int(start)
                    guard.append(frame+len(frames)//2)
                    used.add(int(rows[data['clip_count']+frame*2+1][2])+len(paths))
                snow_guards[len(variants)+skin]=guard
            skin_pages.append(sorted(used))
        for i in range(data['frame_count']):
            rect=rows[data['clip_count']+i*2];x,y,page,palette=rows[data['clip_count']+i*2+1]
            frames.extend((rect,(x,y,page+len(paths),palette+palette_offset)))
        paths.extend('res://'+str((folder/f'atlas-{i}.png').relative_to(ROOT)) for i in range(data['pages']))
        variants.extend(data['variants']);sounds.update(data['sounds'])
        stride=data.get('timeline_stride',28)
        assert stride<=COMPANION_TIMELINE_STRIDE
        for start in range(0,len(data['timelines']),stride):
            timelines.extend(data['timelines'][start:start+stride])
            timelines.extend([0]*(COMPANION_TIMELINE_STRIDE-stride))
        files=['motions.json','frames.bin','palette.png']+[f'atlas-{page}.png' for page in range(data['pages'])]
        if (folder/'portraits.png').exists():files.append('portraits.png')
        for name in files:
            file=folder/name;sources[str(file.relative_to(ROOT))]=hashlib.sha256(file.read_bytes()).hexdigest()
        palettes.append(source_palette);palette_offset+=source_palette.height
    hound_skin=next(i for i,variant in enumerate(variants) if variant['key']==SNOW_HOUND)
    guard_rows=list(struct.iter_unpack('<4f',(SNOW_HOUND_GUARD/'frames.bin').read_bytes()))
    snow_guards[hound_skin]=list(range(len(frames)//2,len(frames)//2+8))
    skin_pages[hound_skin].append(len(paths))
    for direction in range(8):
        rect,(x,y,page,palette)=guard_rows[direction*2:direction*2+2]
        frames.extend((rect,(x,y,page+len(paths),palette+palette_offset)))
    paths.append('res://'+str((SNOW_HOUND_GUARD/'atlas-0.png').relative_to(ROOT)))
    guard_palette=Image.open(SNOW_HOUND_GUARD/'palette.png').convert('RGBA')
    palettes.append(guard_palette);palette_offset+=guard_palette.height
    for file in (SNOW_HOUND_GUARD/'frames.bin',SNOW_HOUND_GUARD/'palette.png',SNOW_HOUND_GUARD/'atlas-0.png'):
        sources[str(file.relative_to(ROOT))]=hashlib.sha256(file.read_bytes()).hexdigest()
    table=clips+frames;table.extend([(0,0,0,0)]*(-len(table)%TABLE_WIDTH))
    BANK.mkdir(parents=True,exist_ok=True)
    (BANK/'frames.bin').write_bytes(b''.join(struct.pack('<4f',*r) for r in table))
    palette=Image.new('RGBA',(256,palette_offset));offset=0
    for image in palettes:palette.paste(image,(0,offset));offset+=image.height
    packed_palette=Image.new('RGBA',(2048,(palette_offset+7)//8))
    for row in range(palette_offset):packed_palette.paste(palette.crop((0,row,256,row+1)),((row%8)*256,row//8))
    packed_palette.save(BANK/'palette.png')
    combined=dict(variants=variants,atlas_paths=paths,pages=len(paths),table_width=TABLE_WIDTH,
                  clip_count=len(clips),frame_count=len(frames)//2,actions=[0,3,5,8,10,1],
                  timelines=timelines,timeline_stride=COMPANION_TIMELINE_STRIDE,sounds=sounds,sources=sources,skin_pages=skin_pages,palette_rows=palette_offset,
                  snow_guards=snow_guards)
    assert len(clips)==len(variants)*48 and len(timelines)==len(variants)*8*COMPANION_TIMELINE_STRIDE
    (BANK/'motions.json').write_text(json.dumps(combined,separators=(',',':'))+'\n')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path)
    recover(parser.parse_args().source)
