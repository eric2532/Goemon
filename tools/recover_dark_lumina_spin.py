"""Trace DL2's code-driven spin/steps and retain its shared flying ground tiles."""
import hashlib
import json
import struct
from recover_dark_lumina import BASE, SOURCE
from recover_skullpion_effects import ROOT, RECOVERY, load_vram, texture, png


def recover():
    data=(RECOVERY/SOURCE).read_bytes()
    overlay_source='raw/SC07.CD.dir/FILE_002.dir/0.4.dec'
    overlay=(RECOVERY/overlay_source).read_bytes();base=0x80128158
    def word(address):return struct.unpack_from('<I',data,address-BASE)[0]
    # Validate the dispatch, clip loads, sound calls, and code-owned rotation.
    expected={0x801a6b68:0x801a13a0,0x801a6b6c:0x801a143c,
              0x801a13e0:0x24a51898,0x801a13f8:0x24a51978,
              0x801a1410:0x24040b56,0x801a1484:0x00031900,
              0x801a14c0:0x00031900,0x801a081c:0x24040b53,
              0x801a07d8:0x2402000f,0x801a07e0:0x24020035}
    for address,value in expected.items():assert word(address)==value,(hex(address),hex(word(address)))
    table=0x80190f40
    assert struct.unpack_from('<I',overlay,table+0x376*4-base)[0]==0x80183a70
    assert struct.unpack_from('<I',overlay,0x80184298-base)[0]==0x24027800
    vram,present=load_vram((RECOVERY/'raw/MAIN.CD.dir/FILE_003').read_bytes())
    for source in ['raw/SC07.CD.dir/FILE_001','raw/SC07.CD.dir/FILE_003']:
        values,mask=load_vram((RECOVERY/source).read_bytes())
        for i,loaded in enumerate(mask):
            if loaded:vram[i]=values[i];present[i]=1
    rects=[(320+x*32,y*32,16,32) for y in range(8) for x in range(4)]
    pixels=b''.join(texture(vram,present,rect,0x7800,8) for rect in rects)
    out=ROOT/'assets/characters/recovered_monsters/dark_lumina_2_effects'
    png(out/'spin_debris.png',32,32*32,pixels)
    report=dict(module=SOURCE,module_sha256=hashlib.sha256(data).hexdigest(),
        overlay=overlay_source,overlay_sha256=hashlib.sha256(overlay).hexdigest(),
        instructions={hex(k):hex(v) for k,v in expected.items()},
        walk=dict(handler='801a079c',sound='0xb53',ticks=[15,53],period=80),
        spin=dict(initializer='801a13a0',handler='801a143c',clips=['Source__801f1898','Source__801f1978'],
                  sound='0xb56',windup_tick=4,windup_angle=-112,active_ticks=[7,25],angle_per_tick=240,
                  particles_per_tick=8,debris_per_tick=1,debris_actor='0x376'),
        debris=dict(handler='80183a70',renderer='80183fe0',frames=32,depth=8,clut=0x7800,rects=rects,
                    rgba_sha256=hashlib.sha256(pixels).hexdigest()),
        notes=['Spin is selected from close-range states, not a hit reaction. B56 layers were previously labelled hurt.',
               'The two spin actions already exist in the immutable recovery and editable Blender master. Rotation is actor yaw, not missing skeletal keys.',
               '801F1FD8 is a reduced-part walking stream, not the breakup. Keep the full-body 801F01F0 walk for the full 19-part Goemon actor.'])
    (out/'spin_sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Recovered spin dispatch, both directional poses, B56, B53 foot markers, and 32 original ground-debris tiles.')


if __name__=='__main__':recover()
