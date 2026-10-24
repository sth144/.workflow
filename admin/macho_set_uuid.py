#!/usr/bin/python3
"""Give a copied Mach-O binary its own LC_UUID, derived from a seed string.

macOS Local Network privacy maps executable UUIDs to bundle ids, so app clones that
share Alacritty's UUID get Alacritty's (or a sibling clone's) policy instead of their own.

Usage: macho_set_uuid.py <binary> <seed>
"""

import hashlib
import struct
import sys

FAT_MAGIC = 0xCAFEBABE
MH_MAGIC_64 = 0xFEEDFACF
LC_UUID = 0x1B


def slice_offsets(data: bytes) -> list[int]:
    """Return the file offset of each architecture slice."""
    if struct.unpack_from(">I", data, 0)[0] != FAT_MAGIC:
        return [0]
    nfat = struct.unpack_from(">I", data, 4)[0]
    return [struct.unpack_from(">5I", data, 8 + 20 * i)[2] for i in range(nfat)]


def set_slice_uuid(data: bytearray, base: int, uuid: bytes) -> bool:
    """Overwrite LC_UUID in the 64-bit slice at base. Return True if found."""
    if struct.unpack_from("<I", data, base)[0] != MH_MAGIC_64:
        return False
    ncmds = struct.unpack_from("<I", data, base + 16)[0]
    off = base + 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<2I", data, off)
        if cmd == LC_UUID:
            data[off + 8:off + 24] = uuid
            return True
        off += size
    return False


def main() -> int:
    path, seed = sys.argv[1], sys.argv[2]
    with open(path, "rb") as f:
        data = bytearray(f.read())
    patched = 0
    for i, base in enumerate(slice_offsets(data)):
        uuid = hashlib.md5(f"{seed}:{i}".encode()).digest()
        patched += set_slice_uuid(data, base, uuid)
    if not patched:
        print(f"macho_set_uuid: no LC_UUID found in {path}", file=sys.stderr)
        return 1
    with open(path, "wb") as f:
        f.write(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
