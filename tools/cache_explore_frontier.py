"""Cache only hash-pinned source files for the audited ordinary-door frontier."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access'
REFERENCES = ROOT / 'assets/references/crossgate_sokia'
COMMIT = 'dd8690ed3df11e4eb5a038a54079a8f40d8e93b3'


def main():
    plan = json.loads((REPORT / 'ordinary-frontier-plan.json').read_text())
    tree = json.loads((REPORT / 'pinned-source-tree.json').read_text())['tree']
    requests = []
    for ident in plan['maps']:
        matches = plan['map_sources'][str(ident)]
        assert len(matches) == 1, (ident, matches)
        requests.append((matches[0], REFERENCES / 'maps/server/frontier', ident))
    scripts = {a['script'] for a in plan['actors'] if a['script'].endswith('.txt')}
    existing = {}
    for name in ['references.json', 'explore-extra-references.json']:
        existing.update({r['file']: r for r in json.loads((REFERENCES / 'events' / name).read_text()) if 'file' in r})
    for name in sorted(scripts):
        local = REFERENCES / 'events' / name
        if local.exists() and name in existing:
            assert hashlib.sha256(local.read_bytes()).hexdigest() == existing[name]['sha256'], name
            continue
        matches = [r for r in tree if r['type'] == 'blob' and Path(r['path']).name == name]
        npc_matches = [r for r in matches if r['path'] == 'gmsv/data/npc/' + name]
        if npc_matches:
            matches = npc_matches
        assert len(matches) == 1, (name, matches)
        requests.append((matches[0], REFERENCES / 'events', None))

    def fetch(request):
        source, folder, ident = request
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / Path(source['path']).name
        url = f'https://raw.githubusercontent.com/linv2/Crossgate_Docker/{COMMIT}/{source["path"]}'
        payload = target.read_bytes() if target.exists() else urllib.request.urlopen(url, timeout=60).read()
        blob = hashlib.sha1(b'blob ' + str(len(payload)).encode() + b'\0' + payload).hexdigest()
        assert len(payload) == source['size'] and blob == source['sha'], source['path']
        if ident is not None:
            from prepare_explore_missing_maps import reference_map
            reference_map(payload, ident)
        if not target.exists():
            target.write_bytes(payload)
        return dict(file=target.name, source=source['path'], url=url, commit=COMMIT,
                    git_blob_sha1=blob, bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest(),
                    **({'map': ident} if ident is not None else {}))

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(fetch, requests))
    for folder, rows in [(REFERENCES / 'maps/server/frontier', [r for r in results if 'map' in r]),
                         (REFERENCES / 'events', [r for r in results if 'map' not in r])]:
        (folder / 'frontier-references.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
    print('EXPLORE_FRONTIER_CACHED', sum('map' in r for r in results), 'maps;', sum('map' not in r for r in results), 'additional scripts')


if __name__ == '__main__':
    main()
