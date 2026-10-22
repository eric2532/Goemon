"""Verify recovered beam assets and shield color math against executable ROM bytes."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
REC=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')
BASE=0x80128158

def signed(x):
    return x-0x100000000 if x&0x80000000 else x

def execute_color(blob, phase, intensity):
    """Execute original pure-MIPS func801816DC, including delay slots and jump table.

    Only the integer instructions reached by this leaf routine are implemented.
    Every unknown opcode fails, rather than silently approximating native behavior.
    """
    reg=[0]*32;reg[4]=phase;reg[5]=intensity;reg[31]=0x80000000
    lo=hi=0;pc=0x801816DC;pending=None
    for _ in range(100):
        if pc==0x80000000:return reg[2]
        word=struct.unpack_from('<I',blob,pc-BASE)[0]
        op=word>>26;rs=(word>>21)&31;rt=(word>>16)&31;rd=(word>>11)&31;sh=(word>>6)&31;f=word&63
        imm=word&65535;si=imm-65536 if imm&32768 else imm
        jump=None
        if op==0:
            if f==0:reg[rd]=reg[rt]<<sh
            elif f==2:reg[rd]=reg[rt]>>sh
            elif f==3:reg[rd]=signed(reg[rt])>>sh
            elif f==8:jump=reg[rs]
            elif f==16:reg[rd]=hi
            elif f==18:reg[rd]=lo
            elif f==24:
                product=(signed(reg[rs])*signed(reg[rt]))&0xffffffffffffffff
                lo=product&0xffffffff;hi=product>>32
            elif f==33:reg[rd]=reg[rs]+reg[rt]
            elif f==35:reg[rd]=reg[rs]-reg[rt]
            elif f==36:reg[rd]=reg[rs]&reg[rt]
            elif f==37:reg[rd]=reg[rs]|reg[rt]
            else:raise AssertionError((hex(pc),hex(word)))
        elif op==1 and rt==1:
            if signed(reg[rs])>=0:jump=pc+4+si*4
        elif op==2:jump=((pc+4)&0xf0000000)|((word&0x3ffffff)<<2)
        elif op==4:
            if reg[rs]==reg[rt]:jump=pc+4+si*4
        elif op==5:
            if reg[rs]!=reg[rt]:jump=pc+4+si*4
        elif op==9:reg[rt]=reg[rs]+si
        elif op==11:reg[rt]=int(reg[rs]<(si&0xffffffff))
        elif op==12:reg[rt]=reg[rs]&imm
        elif op==13:reg[rt]=reg[rs]|imm
        elif op==15:reg[rt]=imm<<16
        elif op==35:reg[rt]=struct.unpack_from('<I',blob,reg[rs]+si-BASE)[0]
        else:raise AssertionError((hex(pc),hex(word)))
        reg=[v&0xffffffff for v in reg];reg[0]=0
        pc=pc+4 if pending is None else pending;pending=jump
    raise AssertionError('Original color function did not return')

def shader_color(phase,intensity):
    # Evaluate the integer-equivalent shader expression for comparison to the ROM.
    phase=phase%1536
    blue=0 if phase<256 or phase>=1280 else phase%256 if phase<512 else 255 if phase<1024 else 255-phase%256
    channels=[blue//4,blue//2,blue]
    return [min(255,c*max(0,intensity)//4096) for c in channels]

def verify(report_path):
    blob=(REC/'raw/SC06.CD.dir/FILE_016.dir/0.4.dec').read_bytes()
    source=ROOT/'assets/characters/recovered_leaders/ed/beam/source.json'
    proof=json.loads(source.read_text())
    assert hashlib.sha256(blob).hexdigest()==proof['source_sha256']
    shader=(ROOT/'assets/characters/recovered_leaders/ed/beam_shield.gdshader').read_text()
    assert 'blend_add' in shader and 'cull_back' in shader and 'ALPHA = 1.0;' in shader
    assert '0.58' not in shader
    tests=0
    for phase in range(1536):
        for tick in range(17):
            intensity=4096-tick*256
            packed=execute_color(blob,phase,intensity)
            actual=[(packed>>shift)&255 for shift in (0,8,16)]
            assert actual==shader_color(phase,intensity),(phase,tick,actual)
            tests+=1
    output_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in source.parent.iterdir() if p.suffix in ('.png','.glb')}
    for name,item in proof['models'].items():assert output_hashes[name+'.glb']==item['glb_sha256']
    normal_checks=0
    for address,path in [(0x801913BC,source.parent/'main.glb'),(0x80192B24,source.parent.parent/'beam_shield.glb')]:
        vt,nv,nt,nn,pt,count,_=struct.unpack_from('<6Ii',blob,address-BASE+12)
        image_path=path.with_name(path.stem+'_normals.png')
        pixels=Image.open(image_path).convert('RGBA');assert pixels.size==(2,nn)
        for index in range(nn):
            x,y,z=struct.unpack_from('<3h',blob,address-BASE+12+nt+index*8)
            low=pixels.getpixel((0,index));high=pixels.getpixel((1,index))
            assert [low[c]+high[c]*256-4096 for c in range(3)]==[x,-y,-z]
            normal_checks+=1
        data=path.read_bytes();n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);binary=data[28+n:]
        for primitive in doc['meshes'][0]['primitives']:
            ac=doc['accessors'][primitive['attributes']['COLOR_0']];bv=doc['bufferViews'][ac['bufferView']];off=bv.get('byteOffset',0)+ac.get('byteOffset',0)
            for i in range(ac['count']):
                value=struct.unpack_from('<f',binary,off+i*12)[0]
                index=round(value*255);assert 0<=index<nn and abs(value-index/255)<1e-7
        output_hashes[path.name]=hashlib.sha256(data).hexdigest()
        output_hashes[image_path.name]=hashlib.sha256(image_path.read_bytes()).hexdigest()
    # Native shield sets attribute0x50000000; custom mesh emitter selects ABR low2bits.
    attr=0x50000000;draw_mode=0xE100000A|((((attr>>28)&7)&3)<<5)
    assert draw_mode==0xE100002A
    # Capture sample bands at source actor ticks and release levels for review.
    samples=[]
    for tick in (1,2,4,8,16,30):
        row={'actor_tick':tick,'bands_rgb':[]}
        for band in range(5):
            phase=(-199*tick+307*band)%1536
            word=execute_color(blob,phase,4096)
            row['bands_rgb'].append([(word>>bit)&255 for bit in (0,8,16)])
        samples.append(row)
    result={'native_function':'0x801816dc','function_sha256':hashlib.sha256(blob[0x801816DC-BASE:0x80181804-BASE]).hexdigest(),
            'original_MIPS_executions':tests,'all_source_phase_and_release_combinations_match':True,
            'shield_actor_attribute':'0x50000000','shield_DR_MODE':hex(draw_mode),'shield_blend':'ABR1 additive B+F',
            'shield_faces':'TMD flags4 lacks double-sided bit2; native emitters reject NCLIP<=0; shader cull_back',
            'first_visible_color_update':'phase=-199 modulo1536, before first color upload',
            'release_factor_Q12':[4096-t*256 for t in range(17)],'sample_colors':samples,
            'output_sha256':output_hashes,
            'native_Q12_normal_rows_checked':normal_checks,
            'scope':'Exact source data, integer color computation, native integer light/color stages and native affine RGB555 rasterizer. The requested smoother presentation filters the foreground over the full-resolution encoded scene without quantizing the background. Modern camera, longer reach and world visibility are port adapters. This does not assert whole-frame equivalence to original gameplay.'}
    gpu_path=report_path.parent/'lighting-gpu-verification.json'
    if gpu_path.exists():
        gpu=json.loads(gpu_path.read_text());assert gpu['failed']==0
        assert len(gpu['checks'])==8 and all(c['max_framebuffer_delta']==0 for c in gpu['checks'])
        result['graphical_fixture_verification']={'report':gpu_path.name,'fixtures':8,'max_framebuffer_delta':0,'sha256':hashlib.sha256(gpu_path.read_bytes()).hexdigest()}
    glow_path=report_path.parent/'glow-position-verification.json'
    if glow_path.exists():
        glow=json.loads(glow_path.read_text());assert glow['passed']
        result['glow_vertex_position_verification']={'report':glow_path.name,'visible_pixel_counts':glow['visible_pixel_counts'],
            'layout':glow['layout'],'sha256':hashlib.sha256(glow_path.read_bytes()).hexdigest()}
    native_path=report_path.parent/'native-rasterizer-verification.json'
    if native_path.exists():
        native=json.loads(native_path.read_text());assert native['passed']
        assert native['reference']['rgb555_and_coverage_mismatches']==0
        for path,digest in native['source_sha256'].items():
            assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
        result['native_rasterizer_verification']={'report':native_path.name,'triangles':native['reference']['triangles'],
            'pixels':native['reference']['pixels'],'rgb555_and_coverage_mismatches':0,
            'sha256':hashlib.sha256(native_path.read_bytes()).hexdigest()}
    presentation_path=report_path.parent/'Beam Smoothing/presentation-tests.json'
    if presentation_path.exists():
        presentation=json.loads(presentation_path.read_text());assert presentation['passed']
        assert presentation['shader_sha256']==hashlib.sha256((source.parent/'native_composite.gdshader').read_bytes()).hexdigest()
        result['smooth_presentation_verification']={'report':str(presentation_path.relative_to(report_path.parent)),
            'checks':len(presentation['checks']),'failures':presentation['failures'],
            'sha256':hashlib.sha256(presentation_path.read_bytes()).hexdigest()}
    result['shader_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [source.parent/'native_lighting.gdshaderinc',source.parent/'native_tube.gdshader',source.parent/'native_glow.gdshader',source.parent/'native_composite.gdshader',source.parent.parent/'beam_shield.gdshader']}
    report_path.parent.mkdir(parents=True,exist_ok=True)
    report_path.write_text(json.dumps(result,indent=2)+'\n')
    print('ED_BEAM_ASSET_VERIFICATION_PASS',tests,'native MIPS color executions;',len(output_hashes),'output hashes;',report_path)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--report',type=Path,default=Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Ed Original Restore/beam-assets-verification.json'))
    verify(p.parse_args().report)
