"""Independent, read-only byte/pixel review of the staged bridge24 completion."""
from pathlib import Path
import base64
import hashlib
import json
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
R = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region'
BASE = R / 'Village Props/Cliff Audit/Source Context Audit/Prototype'
STAGE = BASE / 'Bridge24 Candidate'
AUDIT = R / 'Runtime Audit/Source100 Bridge Edge Audit/reference-owner-piece-addendum.json'
OUT = R / 'Runtime Audit/Source100 Bridge24 Stage Peer Review'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    checks = []

    def check(label, condition):
        assert condition, label
        checks.append(label)

    contract = json.loads((STAGE / 'source-contract.json').read_text())
    original_audit = json.loads(AUDIT.read_text())
    rows = original_audit['raw_completion_plan_only']['tuples']
    expected = {row['index']: row for row in rows}
    check('Independent exact24 audited tuple ledger', contract['changed_tuples'] == rows and len(expected) == 24)
    pins = {path: sha(ROOT / path.removeprefix('res://')) for path in contract['source_hashes']}
    check('All27 producer input pins current', pins == contract['source_hashes'] and len(pins) == 27)
    for name, expected_hash in contract['products'].items():
        check('Staged product hash: ' + name, sha(STAGE / name) == expected_hash)
    before = (BASE / '100.dat').read_bytes()
    after = (STAGE / '100.dat').read_bytes()
    reference = (ROOT / 'build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Server completion/100-client-plus-server.dat').read_bytes()
    canonical = (ROOT / 'assets/maps/falan/freyja_source/100.dat').read_bytes()
    check('Active mergedc022 unchanged', sha(BASE / '100.dat') == original_audit['raw_completion_plan_only']['base_sha256'])
    check('Frozen before-image exact activec022', (STAGE / 'input-c022-100.dat').read_bytes() == before)
    n = 840 * 610
    check('Lengths and raw header exact', len(before) == len(after) == len(reference) == len(canonical) and before[:20] == after[:20])
    a = struct.unpack_from('<' + str(n * 3) + 'H', before, 20)
    b = struct.unpack_from('<' + str(n * 3) + 'H', after, 20)
    ref = struct.unpack_from('<' + str(n * 3) + 'H', reference, 20)
    client = struct.unpack_from('<' + str(n * 3) + 'H', canonical, 20)
    changed = {i for i in range(n) if (a[i], a[n + i]) != (b[i], b[n + i])}
    check('Only audited24 raw tuples changed', changed == set(expected))
    check('Whole marker plane byte-exact', before[20 + n * 4:] == after[20 + n * 4:])
    check('Every recorded/client-known tuple preserved', all((a[i], a[n+i]) == (b[i], b[n+i]) for i in range(n) if a[i] or a[n+i] or a[2*n+i] & 0xc000 or client[i] or client[n+i] or client[2*n+i] & 0xc000))
    check('New tuples exactly pinned source; no marker overwrite', all((b[i], b[n+i]) == tuple(row['pinned_after']) == (ref[i], ref[n+i]) and a[i] == a[n+i] == a[2*n+i] == 0 for i, row in expected.items()))
    before_desc = json.loads((BASE / 'field100-restore.json').read_text())
    after_desc = json.loads((STAGE / 'field100-restore.json').read_text())
    old_bits = base64.b64decode(before_desc['native_walk_bits'])
    new_bits = base64.b64decode(after_desc['native_walk_bits'])
    bit = lambda bits, i: bool(bits[i >> 3] & (1 << (i & 7)))
    opened = {i for i in range(n) if not bit(old_bits, i) and bit(new_bits, i)}
    closed = {i for i in range(n) if bit(old_bits, i) and not bit(new_bits, i)}
    check('Nine walk opens, no closes, six protected', opened == {y * 840 + x for y in range(195, 198) for x in range(437, 440)} and not closed and sum(expected[i]['protected_bridge'] for i in opened) == 6)
    check('All24 target walk identities match prior pinned decoder audit', all(bit(new_bits, i) == row['pinned_reference_open'] for i, row in expected.items()))
    check('Thirteen sourcePG2 controls remain closed', sum(row['pinned_after'][1] == 2 for row in rows) == 13 and all(not bit(new_bits, row['index']) for row in rows if row['pinned_after'][1] == 2))
    old_index = Image.open(BASE / 'freyja_ground_index.png').convert('RGBA')
    new_index = Image.open(STAGE / 'freyja_ground_index.png').convert('RGBA')
    index_diff = {i for i, (old, new) in enumerate(zip(old_index.getdata(), new_index.getdata())) if old != new}
    check('Only24 original-empty index pixels changed', old_index.size == new_index.size == (840, 610) and index_diff == set(expected) and all(old_index.getpixel(tuple(row['cell']))[3] == 0 for row in rows))
    old_atlas = Image.open(BASE / 'freyja_ground_atlas.png').convert('RGB')
    new_atlas = Image.open(STAGE / 'freyja_ground_atlas.png').convert('RGB')
    city = Image.open(ROOT / 'assets/maps/falan/city_paving_atlas.png').convert('RGB')
    check('Atlas dimensions and old612pixel prefix exact', old_atlas.size == new_atlas.size == (1152, 648) and old_atlas.crop((0, 0, 1152, 612)).tobytes() == new_atlas.crop((0, 0, 1152, 612)).tobytes())
    box = lambda slot, cols: ((slot % cols) * 36, (slot // cols) * 36, (slot % cols + 1) * 36, (slot // cols + 1) * 36)
    old_slots = {p[0] + p[1] * 32 for p in old_index.getdata() if p[3]}
    check('All533 pre-existing bound tiles exact', len(old_slots) == 533 and all(old_atlas.crop(box(slot, 32)).tobytes() == new_atlas.crop(box(slot, 32)).tobytes() for slot in old_slots))
    changed_slots = {slot for slot in range(576) if old_atlas.crop(box(slot, 32)).tobytes() != new_atlas.crop(box(slot, 32)).tobytes()}
    check('Atlas writes confined to three previously unbound padding slots', changed_slots == {545, 546, 547} and not changed_slots & old_slots)
    for target, source in [(545, 13), (546, 14), (547, 17)]:
        check('Exact existingCity tile copy ' + str(target), new_atlas.crop(box(target, 32)).tobytes() == city.crop(box(source, city.width // 36)).tobytes())
    check('All24 index slots match staged bindings', all(new_index.getpixel(tuple(row['cell'])) == tuple(row['rgba']) for row in contract['ground']['bindings']))
    owners = json.loads((STAGE / 'owner-preservation.json').read_text())['existing_owners']
    check('Allthree existingFalan owner proofs retained verbatim', owners == original_audit['halo_graphic_owner_proof'] and {row['graphic'] for row in owners} == {10653, 10661, 10662})
    check('No input changed during review', all(sha(ROOT / path.removeprefix('res://')) == digest for path, digest in pins.items()))
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'scope': 'READ_ONLY independent raw/index/atlas/owner review; no producer imports, no stage/shared writes, no actual field or Native acceptance.', 'checks_passed': len(checks), 'checks': checks, 'findings': [], 'stage_contract_sha256': sha(STAGE / 'source-contract.json'), 'active_raw_sha256': sha(BASE / '100.dat'), 'candidate_raw_sha256': sha(STAGE / '100.dat'), 'peer_script_sha256': sha(Path(__file__)), 'source_hashes': pins, 'limits': 'Target walk identity compared independently to prior pinned-source decoder audit, not a new server-motion proof. Host fields/common heights/routes/activation and rendered mips remain unfinished.'}
    (OUT / 'review.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'checks_passed': len(checks), 'findings': [], 'active_raw_unchanged': report['active_raw_sha256'], 'candidate_raw': report['candidate_raw_sha256']}))


if __name__ == '__main__':
    main()
