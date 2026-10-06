"""Slices a generated icon sheet (icons on a plain white background) into transparent PNG icons.

The background is found by flood-filling near-white pixels from the image border, so white
highlights *inside* an icon (behind its dark outline) are kept. Icons are then found as connected
blobs, grouped into rows and named in reading order.

  python3 -I tools/ui/slice_icons.py assets/ui/source/sheet_a.png assets/ui
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

NAMES = [
    "coin", "nugget", "wheel", "boots",
    "shop", "gift", "settings", "moneybag",
    "crate", "crown", "horseshoe", "scroll",
    "egg", "book", "lock", "firework",
]
SIZE = 256  # output icons are SIZE x SIZE with padding


def main(sheet_path: str, out_dir: str) -> None:
    img = Image.open(sheet_path).convert("RGB")
    rgb = np.asarray(img).astype(np.int16)
    near_white = (rgb.min(axis=2) > 232) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 18)
    # Background = near-white regions connected to the border.
    labels, _ = ndimage.label(near_white)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    border.discard(0)
    background = np.isin(labels, list(border))
    alpha = np.where(background, 0, 255).astype(np.uint8)
    # Soften the cut edge a little so icons don't look jagged.
    alpha_img = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.8))
    rgba = img.convert("RGBA")
    rgba.putalpha(alpha_img)

    # The sheet is a 4 x 4 grid. Find column/row boundaries from the empty gaps in the foreground
    # (the emptiest vertical/horizontal lines between icons), then crop each cell to its contents.
    fg = ~background
    def cuts(profile: np.ndarray, parts: int) -> list[int]:
        size = len(profile)
        result = [0]
        for k in range(1, parts):
            centre = size * k // parts
            window = range(int(centre - size * 0.08), int(centre + size * 0.08))
            result.append(min(window, key=lambda i: profile[i]))
        result.append(size)
        return result

    xs = cuts(fg.sum(axis=0), 4)
    ys = cuts(fg.sum(axis=1), 4)
    ordered = []
    for r in range(4):
        for c in range(4):
            cell = fg[ys[r] : ys[r + 1], xs[c] : xs[c + 1]]
            rows_any, cols_any = np.where(cell.any(axis=1))[0], np.where(cell.any(axis=0))[0]
            if len(rows_any) == 0:
                raise SystemExit(f"empty cell {r},{c}")
            ordered.append([
                xs[c] + int(cols_any[0]), ys[r] + int(rows_any[0]),
                xs[c] + int(cols_any[-1]) + 1, ys[r] + int(rows_any[-1]) + 1,
            ])

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for name, box in zip(NAMES, ordered):
        crop = rgba.crop(tuple(box))
        side = max(crop.size)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(crop, ((side - crop.size[0]) // 2, (side - crop.size[1]) // 2))
        pad = int(SIZE * 0.06)
        canvas = canvas.resize((SIZE - 2 * pad, SIZE - 2 * pad), Image.LANCZOS)
        final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        final.paste(canvas, (pad, pad))
        final.save(out / f"{name}.png")
        print(f"{name}.png  from {box[0]},{box[1]} {crop.size}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
