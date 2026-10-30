"""Package the supplied PNG for Android launchers; requires Pillow.

Run from any directory. Keeps the source artwork intact, centers its alpha bounds,
and sizes the adaptive foreground inside a 64 dp safe circle on a 108 dp layer.
"""
from pathlib import Path
import math

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/branding/launcher-source.png'
RES = ROOT / 'android/app/src/main/res'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def centered_art(source: Image.Image, side: int, diameter: float) -> Image.Image:
    # Use every non-transparent source pixel when determining the safe radius.
    bounds = source.getchannel('A').getbbox()
    if bounds is None:
        raise ValueError('Launcher source has no visible pixels')
    art = source.crop(bounds)
    cx, cy = art.width / 2, art.height / 2
    alpha = art.getchannel('A')
    radius = max(
        math.hypot(x + .5 - cx, y + .5 - cy)
        for y in range(art.height)
        for x in range(art.width)
        if alpha.getpixel((x, y))
    )
    # Two pixels of extra clearance include the resampling filter's edge.
    scale = (diameter / 2 - 2) / radius
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.Resampling.LANCZOS,
    )
    layer = Image.new('RGBA', (side, side))
    layer.alpha_composite(art, ((side - art.width) // 2, (side - art.height) // 2))
    return layer


def main() -> None:
    with Image.open(SOURCE) as image:
        source = image.convert('RGBA')
    foreground = centered_art(source, 432, 256)
    for density, multiplier in DENSITIES.items():
        folder = RES / f'mipmap-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        side = round(108 * multiplier)
        foreground.resize((side, side), Image.Resampling.LANCZOS).save(
            folder / 'ic_launcher_foreground.png', optimize=True
        )
        # Android 7 fallback: an opaque white canvas with the same supplied art.
        side = round(48 * multiplier)
        layer = centered_art(source, side, side * .9)
        legacy = Image.new('RGBA', (side, side), 'white')
        legacy.alpha_composite(layer)
        legacy.convert('RGB').save(folder / 'ic_launcher.png', optimize=True)
    adaptive = RES / 'mipmap-anydpi-v26'
    adaptive.mkdir(parents=True, exist_ok=True)
    (adaptive / 'ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''', encoding='utf-8')
    (RES / 'values/launcher_colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
''', encoding='utf-8')
    print('Generated legacy and adaptive launcher icons for five Android densities.')


if __name__ == '__main__':
    main()
