"""Read the supplied GameCube RVZ without modifying it or expanding a whole ISO.

Format: dolphin-emu/dolphin docs/WiaAndRvz.md. Only GameCube/Zstandard is
needed here; other formats fail explicitly. Uses the installed libzstd.
"""
import ctypes
import ctypes.util
import functools
import hashlib
from pathlib import Path
import struct


class Disc:
    def __init__(self, path):
        self.file = Path(path).open('rb')
        head = self.file.read(0x48)
        assert head[:4] == b'RVZ\1', 'Expected RVZ'
        assert hashlib.sha1(head[:0x34]).digest() == head[0x34:]
        size = struct.unpack_from('>I', head, 12)[0]
        disc = self.file.read(size)
        assert hashlib.sha1(disc).digest() == head[16:36]
        kind, compression, _, self.chunk = struct.unpack_from('>4I', disc)
        assert kind == 1 and compression == 5, 'Requires GameCube/Zstandard RVZ'
        self.header = disc[16:144]
        self.zstd = ctypes.CDLL(ctypes.util.find_library('zstd') or '/opt/homebrew/lib/libzstd.dylib')
        self.zstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
        self.zstd.ZSTD_decompress.restype = ctypes.c_size_t
        self.zstd.ZSTD_isError.argtypes = [ctypes.c_size_t]
        self.zstd.ZSTD_isError.restype = ctypes.c_uint
        count, offset, length = struct.unpack_from('>IQI', disc, 0xb4)
        self.raw = list(struct.iter_unpack('>QQII', self.unpack(offset, length, count * 24)))
        count, offset, length = struct.unpack_from('>IQI', disc, 0xc4)
        self.groups = list(struct.iter_unpack('>III', self.unpack(offset, length, count * 12)))

    def unpack(self, offset, size, capacity, compressed=True):
        self.file.seek(offset)
        data = self.file.read(size)
        assert len(data) == size, 'Truncated RVZ'
        if not compressed:
            return data
        out = ctypes.create_string_buffer(capacity)
        length = self.zstd.ZSTD_decompress(out, capacity, data, size)
        assert not self.zstd.ZSTD_isError(length), 'Invalid Zstandard block'
        return out.raw[:length]

    @functools.lru_cache(maxsize=16)
    def block(self, index, disc_offset):
        offset, size, packed = self.groups[index]
        if size & 0x7fffffff == 0:
            return bytes(self.chunk)
        data = self.unpack(offset * 4, size & 0x7fffffff, packed or self.chunk, bool(size >> 31))
        if not packed:
            return data
        result = bytearray()
        pos = 0
        while pos < len(data):
            size, = struct.unpack_from('>I', data, pos)
            pos += 4
            if size >> 31:
                count = size & 0x7fffffff
                result.extend(padding(data[pos:pos+68], count, disc_offset + len(result)))
                pos += 68
            else:
                assert pos + size <= len(data)
                result.extend(data[pos:pos+size])
                pos += size
        return bytes(result)

    def read(self, offset, size):
        result = bytearray()
        while size:
            if offset < 0x80:
                data = self.header[offset:offset+size]
            else:
                region = next((r for r in self.raw if r[0] <= offset < r[0]+r[1]), None)
                assert region is not None, 'Read outside disc'
                start = region[0] & ~0x7fff
                index, inside = divmod(offset-start, self.chunk)
                data = self.block(region[2]+index, start+index*self.chunk)[inside:inside+size]
            assert data, 'Truncated disc block'
            result.extend(data)
            offset += len(data)
            size -= len(data)
        return bytes(result)

    def files(self):
        offset, size = struct.unpack('>II', self.read(0x424, 8))
        fst = self.read(offset, size)
        count, = struct.unpack_from('>I', fst, 8)
        assert count * 12 <= size
        stack = [('', count)]
        result = {}
        for index in range(1, count):
            while index >= stack[-1][1]:
                stack.pop()
            name, start, length = struct.unpack_from('>III', fst, index*12)
            at = count*12 + (name & 0xffffff)
            label = fst[at:fst.index(0, at)].decode('ascii')
            assert label not in ('.', '..') and '/' not in label
            path = stack[-1][0] + label
            if name >> 24:
                stack.append((path+'/', length))
            else:
                result[path] = (start, length)
        return result


def padding(seed, size, offset):
    words = list(struct.unpack('>17I', seed))
    for i in range(17, 521):
        words.append(((words[i-17] << 23) ^ (words[i-16] >> 9) ^ words[i-1]) & 0xffffffff)
    def advance():
        for i in range(521):
            words[i] ^= words[(i-32) % 521]
    for _ in range(4):
        advance()
    skip = offset % 0x8000
    data = bytearray()
    while len(data) < skip+size:
        for word in words:
            data.extend((word >> 24, (word >> 18) & 255, (word >> 8) & 255, word & 255))
        advance()
    return data[skip:skip+size]


if __name__ == '__main__':
    import sys
    disc = Disc(sys.argv[1])
    assert disc.read(0, 6) == b'GXSP8P', 'Not the supplied European SADX disc'
    for name, (offset, size) in disc.files().items():
        print(f'{offset:08x} {size:9d} {name}')
