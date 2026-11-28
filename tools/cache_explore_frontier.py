"""Cache only hash-pinned source files for the audited ordinary-door frontier."""
import concurrent.futures
import hashlib
import json
import argparse
import re
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'build/Other Files/Asset Toolkit/Explore Access'
REFERENCES = ROOT / 'assets/references/crossgate_sokia'
COMMIT = 'dd8690ed3df11e4eb5a038a54079a8f40d8e93b3'


def extend_script_frontier(plan, tree, scan_active=False):
    inventory = json.loads((REPORT / 'runtime-inventory.json').read_text())
    available = {int(row['source']) for row in inventory['maps'] if row.get('available_source')}
    assert inventory.get('known_sources'), 'Refresh the runtime inventory before extending beyond native doors'
    available.update(map(int, inventory['known_sources']))
    available.update([100, 300, 1000, 1500, 2000, 2400, 5009, 5010])
    bundled = {int(row['id']) for row in json.loads((ROOT / 'assets/maps/original_crossgate/explore_recovered/catalog.json').read_text())['maps'].values()}
    wanted = set(plan['maps']) | {int(row['target']) for row in inventory['missing_script_destinations']}
    # Newly prepared scripts can expose another source frontier before the next runtime census.
    routes = json.loads((ROOT / 'assets/maps/falan/explore-access.json').read_text())['routes']
    wanted.update(int(row['target']) for source, rows in routes.items() if int(source) in available | bundled
                  for row in rows if int(row['target']) not in available | bundled)
    wanted -= available - bundled
    warps = json.loads((ROOT / 'assets/maps/original_crossgate/catalog.json').read_text())['warps']
    from audit_explore_access import transfers, housing_routes
    wanted.update(row['target'] for row in housing_routes() if row['source'] in available | bundled)
    wanted -= available - bundled
    from prepare_east_region_population import compile_script
    actor_rows = [line.split('\t') for line in (ROOT / 'assets/references/crossgate_tina/events/npc.txt').read_bytes().decode('gb18030').splitlines()
                  if not line.startswith('#')]
    actor_rows = [row for row in actor_rows if len(row) == 25 and row[8].isdigit() and row[6] == '1']
    references = {}
    for name in ['references.json', 'explore-extra-references.json', 'frontier-references.json']:
        references.update({row['file']: row for row in json.loads((REFERENCES / 'events' / name).read_text())})
    compiled = {}
    while True:
        additional = {int(row[3]) for row in warps if int(row[0]) in wanted and int(row[3]) not in available}
        for row in actor_rows:
            if int(row[8]) not in (wanted | available if scan_active else wanted): continue
            actor = dict(type=row[0], script=row[24])
            path = REFERENCES / 'events' / row[24]
            if row[24].endswith('.txt') and path.exists() and row[24] in references:
                if row[24] not in compiled:
                    payload = path.read_bytes()
                    assert hashlib.sha256(payload).hexdigest() == references[row[24]]['sha256'], row[24]
                    compiled[row[24]] = compile_script(payload)
            additional.update(target for _, target, _, _ in transfers(actor, compiled) if target not in available)
        if additional <= wanted:
            break
        wanted.update(additional)
    sources = {}
    for row in tree:
        if row['type'] != 'blob' or '/map/' not in row['path']:
            continue
        match = re.search(r'\d+', Path(row['path']).name)
        if match:
            sources.setdefault(int(match[0]), []).append(row)
    plan['unresolved_map_sources'] = [dict(map=i, candidates=sources.get(i, [])) for i in sorted(wanted) if len(sources.get(i, [])) != 1]
    plan['maps'] = sorted(i for i in wanted if len(sources.get(i, [])) == 1)
    plan['map_sources'] = {str(i): sources[i] for i in plan['maps']}
    actors = []
    for text in (ROOT / 'assets/references/crossgate_tina/events/npc.txt').read_bytes().decode('gb18030').splitlines():
        row = text.split('\t')
        if text.startswith('#') or len(row) != 25 or not row[8].isdigit() or int(row[8]) not in wanted or row[6] != '1':
            continue
        actors.append(dict(id=row[3], source=int(row[8]), type=row[0], name=row[1], script=row[24], graphic=int(row[20] or 0)))
    plan['actors'] = actors
    (REPORT / 'ordinary-frontier-plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2) + '\n')
    print('EXPLORE_SCRIPT_FRONTIER', len(plan['maps']), 'pinned destinations;', len(plan['unresolved_map_sources']), 'missing/ambiguous source maps')


def main(script_frontier=False, active_scripts=False):
    plan = json.loads((REPORT / 'ordinary-frontier-plan.json').read_text())
    tree = json.loads((REPORT / 'pinned-source-tree.json').read_text())['tree']
    if script_frontier:
        extend_script_frontier(plan, tree, scan_active=active_scripts)
    if active_scripts:
        inventory = json.loads((REPORT / 'runtime-inventory.json').read_text())
        sources = {int(row['source']) for row in inventory['maps'] if row.get('available_source')}
        sources.update(map(int, inventory['known_sources']))
        sources.update([100,300,1000,1500,2000,2100,2300,2400,3000,3200])
        actors = {(int(row['source']),str(row['id']),row['script']):row for row in plan['actors']}
        for line in (ROOT / 'assets/references/crossgate_tina/events/npc.txt').read_bytes().decode('gb18030').splitlines():
            raw = line.split('\t')
            if line.startswith('#')or len(raw)!=25 or raw[6]!='1' or not raw[8].isdigit() or int(raw[8])not in sources or not raw[24].endswith('.txt'):continue
            row=dict(id=raw[3],source=int(raw[8]),type=raw[0],name=raw[1],script=raw[24],graphic=int(raw[20]or 0))
            actors[(row['source'],row['id'],row['script'])]=row
        plan['actors']=list(actors.values())
    requests = []
    for ident in plan['maps']:
        matches = plan['map_sources'][str(ident)]
        assert len(matches) == 1, (ident, matches)
        requests.append((matches[0], REFERENCES / 'maps/server/frontier', ident))
    scripts = {a['script'] for a in plan['actors'] if a['script'].endswith('.txt')}
    existing = {}
    for name in ['references.json', 'explore-extra-references.json']:
        existing.update({r['file']: r for r in json.loads((REFERENCES / 'events' / name).read_text()) if 'file' in r})
    unresolved_scripts = []
    for name in sorted(scripts):
        local = REFERENCES / 'events' / name
        if local.exists() and name in existing:
            assert hashlib.sha256(local.read_bytes()).hexdigest() == existing[name]['sha256'], name
            continue
        matches = [r for r in tree if r['type'] == 'blob' and Path(r['path']).name == name]
        npc_matches = [r for r in matches if r['path'] == 'gmsv/data/npc/' + name]
        if npc_matches:
            matches = npc_matches
        if len(matches) != 1:
            unresolved_scripts.append(dict(file=name, candidates=matches, actors=[a for a in plan['actors'] if a['script'] == name],
                reason='The pinned source tree has no unique original event script; no dialogue, destination or reward is inferred.'))
            continue
        requests.append((matches[0], REFERENCES / 'events', None))
    plan['unresolved_script_sources'] = unresolved_scripts
    (REPORT / 'ordinary-frontier-plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2) + '\n')

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
    print('EXPLORE_FRONTIER_CACHED', sum('map' in r for r in results), 'maps;', sum('map' not in r for r in results), 'additional scripts;', len(unresolved_scripts), 'missing/ambiguous original scripts')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--script-frontier', action='store_true')
    parser.add_argument('--active-scripts', action='store_true')
    args=parser.parse_args();main(script_frontier=args.script_frontier,active_scripts=args.active_scripts)
