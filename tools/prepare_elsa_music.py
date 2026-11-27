"""Prepare original PUK2 playback copies and retain native map sound IDs."""
import json
import subprocess
import struct
import wave
import recover_elsa_island as source

OUT=source.ROOT/'assets/audio/crossgate/music'
TRACKS=['puk2_field1','puk2_mati','puk2_sinden','PUK2_haikyo']


def build():
    tracks={}
    for name in TRACKS:
        original=source.cg.SOURCE/f'bgm/{name}.wav'
        target=OUT/(name.lower()+'.mp3')
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(original),'-c:a','libmp3lame','-q:a','2',str(target)],check=True)
        with wave.open(str(original)) as audio:
            rate=audio.getframerate();channels=audio.getnchannels();frames=audio.getnframes()
        decoded=subprocess.check_output(['ffmpeg','-v','error','-i',str(target),'-f','s16le','-'])
        assert len(decoded)//(2*channels)==frames,(name,frames,len(decoded)//(2*channels))
        tracks[name.lower()]=dict(source=f'BlueCrossgate/bin/bgm/{name}.wav',source_sha256=source.sha(original.read_bytes()),
            runtime_sha256=source.sha(target.read_bytes()),duration=frames/rate,decoded_frames=frames,sample_rate=rate,channels=channels)
        print('ELSA_MUSIC',name,frames,'original frames preserved',flush=True)
    path=OUT/'provenance.json';provenance=json.loads(path.read_text());provenance['tracks'].update(tracks)
    provenance['preparation']='ffmpeg -i SOURCE.wav -c:a libmp3lame -q:a 2 OUTPUT.mp3; original sample rate and stereo; decoded frame count matches source; no trims or normalization'
    path.write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
    path=source.OUTPUT/'catalog.json';catalog=json.loads(path.read_text())
    for row in catalog['maps'].values():
        row['music']=struct.unpack_from('>H',(source.SOURCE/str(row['id'])).read_bytes(),56)[0]
    path.write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':'))+'\n')


if __name__=='__main__':build()
