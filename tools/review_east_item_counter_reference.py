"""Read-only legacy item-counter evidence; never execute the server binary."""
import hashlib
import json
from pathlib import Path
import re
import struct

from capstone import Cs, CS_ARCH_X86, CS_MODE_32
from capstone.x86_const import X86_OP_IMM

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Other Files/Asset Toolkit/East Gate Region/Source Audit/Engine Reference'
BINARY_SHA = '176a44e11f834f527c9a07f205d1c5de89267ab5c1405bb1ac5f2cd3a5437ea8'
HANDLERS = {
    'ITEM_useMystery', 'NPC_ItemCountWindowTalked', 'NPC_ItemCountLoop',
    'NPC_ItemCountInit', 'SetGlobalTimer', 'ResetCountItemNum', 'set_object',
    'windowitemcountmain_select_none', 'SetCountItemID', 'CheckMaxCountItemID',
    'Read_ItemCountData', 'OpenItemCountWindow', 'OpenItemCountMainWindow',
    'Get_Evalnum', 'Evaluating_Expression', 'SetObjectFile', 'Exec_Command',
}


def normalize(line):
    return re.sub(r'\s+', '', line.split('#', 1)[0]).casefold()


def review():
    binary = (OUT / 'awafer-gmsv-reference.bin').read_bytes()
    assert hashlib.sha256(binary).hexdigest() == BINARY_SHA
    assert binary[:6] == b'\x7fELF\x01\x01'
    offset = struct.unpack_from('<I', binary, 32)[0]
    stride, count = struct.unpack_from('<HH', binary, 46)
    sections = [struct.unpack_from('<10I', binary, offset + i * stride)
                for i in range(count)]
    symbols = []
    for section in sections:
        if section[1] not in (2, 11):
            continue
        strings = sections[section[6]]
        names = binary[strings[4]:strings[4] + strings[5]]
        for at in range(section[4], section[4] + section[5], section[9]):
            name, address, size, info, _, index = struct.unpack_from('<IIIBBH', binary, at)
            if name:
                text = names[name:names.index(b'\0', name)].decode('ascii')
                symbols.append(dict(name=text, address=address, size=size,
                                    type=info & 15, section=index))
    labels = {s['address']: s['name'] for s in symbols if s['type'] == 2}
    decoder = Cs(CS_ARCH_X86, CS_MODE_32)
    decoder.detail = True
    calls = {}
    for symbol in symbols:
        if symbol['name'] not in HANDLERS or not symbol['size']:
            continue
        section = sections[symbol['section']]
        offset = section[4] + symbol['address'] - section[3]
        lines, called = [], []
        for instruction in decoder.disasm(binary[offset:offset + symbol['size']], symbol['address']):
            line = f'{instruction.address:08x} {instruction.mnemonic:8s} {instruction.op_str}'
            if instruction.mnemonic == 'call' and instruction.operands[0].type == X86_OP_IMM:
                target = labels.get(instruction.operands[0].imm, '?')
                called.append(target)
                line += ' ; ' + target
            lines.append(line)
        key = symbol['name'] + '-' + hex(symbol['address'])
        (OUT / (key + '.asm.txt')).write_text('\n'.join(lines) + '\n')
        calls[key] = called
    assert 'MAP_setTileAndObjData' in calls['set_object-0x8141094']
    assert 'read_command_fileItem' in calls['ITEM_useMystery-0x80ec970']
    assert 'time@@GLIBC_2.0' in calls['NPC_ItemCountLoop-0x81423bc']
    assert 'save_workarea' in calls['NPC_ItemCountLoop-0x81423bc']
    population = json.loads((ROOT / 'assets/maps/falan/east_region/population.json').read_text())
    program = population['scripts']['CNT_rk_7odr.txt']
    reference = (OUT / 'CNT_rk_7odr-awafer-decoded.txt').read_text()
    left = [normalize(line) for line in reference.splitlines() if normalize(line)]
    right = [normalize(line) for _, line in program['lines'] if normalize(line)]
    assert left == right and len(left) == 26
    report = dict(binary_sha256=BINARY_SHA, semantic_script_lines=len(left),
                  pinned_script_sha256=program['sha256'], handler_calls=calls,
                  scope='Read-only disassembly/reference-program corroboration. No binary execution, '
                        'pinned-engine equivalence, runtime gate implementation or route acceptance.')
    (OUT / 'handler-static-review.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Verified legacy handler call targets and26matching source command lines; no server executed.')


if __name__ == '__main__':
    review()
