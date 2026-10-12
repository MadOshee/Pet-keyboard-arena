"""Makes a Studio-saved .rbxl readable by Lune.

Studio compresses chunks with zstd and writes the Tags property in a format
Lune 0.8 rejects. This rewrites the file with uncompressed chunks and
without the listed properties (Tags by default):

    python3 tools/pack/clean_rbxl.py world/source/StealMap6.rbxl /tmp/map.rbxl

Needs the `zstandard` package (python3 -m pip install zstandard).
"""

import struct
import sys

import zstandard


def clean(data: bytes, drop: set[str]) -> bytes:
    out = bytearray(data[:32])  # header
    offset = 32
    dctx = zstandard.ZstdDecompressor()
    while offset < len(data):
        name = data[offset : offset + 4]
        compressed, size = struct.unpack("<II", data[offset + 4 : offset + 12])
        reserved = data[offset + 12 : offset + 16]
        body = data[offset + 16 : offset + 16 + (compressed or size)]
        offset += 16 + (compressed or size)
        if compressed:
            if body[:4] != b"\x28\xb5\x2f\xfd":
                sys.exit("chunk is not zstd-compressed (lz4 files load in Lune as is)")
            body = dctx.decompress(body, max_output_size=size)
        if name == b"PROP":
            length = struct.unpack("<I", body[4:8])[0]
            if body[8 : 8 + length].decode() in drop:
                continue
        out += name + struct.pack("<II", 0, len(body)) + reserved + body
        if name == b"END\x00":
            break
    return bytes(out)


if __name__ == "__main__":
    source, target = sys.argv[1], sys.argv[2]
    drop = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else {"Tags"}
    with open(source, "rb") as f:
        result = clean(f.read(), drop)
    with open(target, "wb") as f:
        f.write(result)
    print(f"{target}: {len(result)} bytes")
