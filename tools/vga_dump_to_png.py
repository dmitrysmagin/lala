"""Render AUTO*.BIN (320x200 + 768-byte 6-bit DAC) to PNG."""
import pathlib
import sys

try:
    from PIL import Image
except ImportError:
    Image = None


def render(src: pathlib.Path, dst: pathlib.Path) -> None:
    data = src.read_bytes()
    if len(data) < 64000 + 768:
        raise SystemExit("%s: expected 64768 bytes, got %d" % (src, len(data)))
    pixels = data[:64000]
    dac = data[64000:64000 + 768]
    img = Image.new("RGB", (320, 200))
    out = []
    for i in range(64000):
        c = pixels[i]
        r, g, b = dac[c * 3], dac[c * 3 + 1], dac[c * 3 + 2]
        out.append((r * 255 // 63, g * 255 // 63, b * 255 // 63))
    img.putdata(out)
    img.save(dst)
    print("wrote", dst)


def main() -> None:
    if Image is None:
        raise SystemExit("Pillow is required")
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "bin")
    for name in ("AUTO1.BIN", "AUTO2.BIN", "AUTO3.BIN", "AUTO4.BIN"):
        src = root / name
        if src.exists():
            render(src, src.with_suffix(".png"))


if __name__ == "__main__":
    main()
