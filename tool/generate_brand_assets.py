"""Generate platform assets from the approved Guided S Path geometry."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
NAVY = "#111A33"
LIGHT = "#E8EEF7"
PRIMARY = "#315EA8"
SECONDARY = "#317C78"
ACCENT = "#C98735"


def path(scale, offset, commands, color, canvas):
    points = []
    current = (0, 0)
    for command, values in commands:
        if command in ("moveto", "lineto"):
            current = values
            points.append(current)
        elif command == "curveto":
            start = current
            c1, c2, end = values[:2], values[2:4], values[4:6]
            for step in range(1, 17):
                t = step / 16
                u = 1 - t
                points.append((u**3*start[0] + 3*u*u*t*c1[0] + 3*u*t*t*c2[0] + t**3*end[0],
                               u**3*start[1] + 3*u*u*t*c1[1] + 3*u*t*t*c2[1] + t**3*end[1]))
            current = end
    ox, oy = offset
    transformed = [(x * scale + ox, y * scale + oy) for x, y in points]
    ImageDraw.Draw(canvas).polygon(transformed, fill=color)


UPPER = [("moveto", (8, 24)), ("lineto", (15, 29)),
         ("curveto", (31, 18, 54, 13, 77, 17)), ("lineto", (93, 25)),
         ("lineto", (84, 30)), ("curveto", (70, 33, 61, 40, 52, 48)),
         ("curveto", (45, 54, 38, 57, 30, 55)),
         ("curveto", (20, 52, 13, 46, 8, 40)), ("close", ())]
LOWER = [("moveto", (92, 58)), ("lineto", (85, 63)),
         ("curveto", (70, 63, 60, 69, 50, 77)),
         ("curveto", (42, 84, 34, 88, 24, 85)), ("lineto", (7, 76)),
         ("lineto", (16, 72)), ("curveto", (30, 69, 39, 62, 48, 54)),
         ("curveto", (55, 48, 62, 44, 70, 46)),
         ("curveto", (80, 48, 87, 54, 92, 58)), ("close", ())]


def mark(size, background=None, padding=.20, monochrome=False):
    image = Image.new("RGBA", (size, size), background or (0, 0, 0, 0))
    scale = size * (1 - 2 * padding) / 100
    offset = (size * padding, size * padding)
    colors = ("#FFFFFF", "#FFFFFF", "#FFFFFF") if monochrome else (PRIMARY, SECONDARY, ACCENT)
    path(scale, offset, UPPER, colors[0], image)
    path(scale, offset, LOWER, colors[1], image)
    draw = ImageDraw.Draw(image)
    cx, cy, radius = 85 * scale + offset[0], 38 * scale + offset[1], 4.8 * scale
    draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=colors[2])
    return image


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


android = ROOT / "android/app/src/main/res"
for density, legacy, adaptive in [("mdpi",48,108),("hdpi",72,162),("xhdpi",96,216),("xxhdpi",144,324),("xxxhdpi",192,432)]:
    composed = mark(legacy, NAVY)
    save(composed, android / f"mipmap-{density}/ic_launcher.png")
    save(composed, android / f"mipmap-{density}/ic_launcher_round.png")
    save(mark(adaptive, None, .20), android / f"drawable-{density}/ic_launcher_foreground.png")
    save(mark(adaptive, None, .20, True), android / f"drawable-{density}/ic_launcher_monochrome.png")
save(mark(192, None, .18), android / "drawable-xxxhdpi/launch_mark.png")

ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for file in ios.glob("*.png"):
    size = int(Image.open(file).size[0])
    save(mark(size, NAVY), file)
launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
for name, size in [("LaunchImage.png",168),("LaunchImage@2x.png",336),("LaunchImage@3x.png",504)]:
    save(mark(size, None, .18), launch / name)

web = ROOT / "web"
save(mark(16, NAVY, .16), web / "favicon-16.png")
save(mark(32, NAVY, .16), web / "favicon-32.png")
save(mark(32, NAVY, .16), web / "favicon.png")
save(mark(180, NAVY), web / "icons/apple-touch-icon.png")
for size in (192, 512):
    save(mark(size, NAVY), web / f"icons/Icon-{size}.png")
    save(mark(size, NAVY, .24), web / f"icons/Icon-maskable-{size}.png")

ico = ROOT / "windows/runner/resources/app_icon.ico"
base = mark(256, NAVY, .16).convert("RGBA")
base.save(ico, format="ICO", sizes=[(s, s) for s in (16,20,24,32,40,48,64,128,256)])
