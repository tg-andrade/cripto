"""Render the CryptoHub vector mark into native launcher sizes."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BG = "#0B0F13"
ACCENT = "#D8FA7A"

def bezier(start, a, b, end):
    return [
        tuple((1-t)**3 * start[i] + 3*(1-t)**2*t*a[i] + 3*(1-t)*t*t*b[i] + t**3*end[i] for i in (0, 1))
        for t in [step / 40 for step in range(41)]
    ]

def icon(size):
    scale = max(4, int(size / 108) + 2)
    extent = 108 * scale
    image = Image.new("RGB", (extent, extent), BG)
    draw = ImageDraw.Draw(image)
    segments = [
        ((76,31), (68,23), (51,21), (39,31)),
        ((39,31), (24,44), (24,65), (39,77)),
        ((39,77), (50,88), (67,87), (76,77)),
    ]
    points = [p for segment in segments for p in bezier(*segment)]
    def line(coords, width):
        scaled = [(round(x*scale), round(y*scale)) for x,y in coords]
        draw.line(scaled, fill=ACCENT, width=round(width*scale), joint="curve")
        radius = width*scale/2
        for x,y in (scaled[0], scaled[-1]):
            draw.ellipse((x-radius,y-radius,x+radius,y+radius), fill=ACCENT)
    line(points, 9)
    line([(46,61),(57,50),(66,55),(80,40)], 5)
    line([(69,40),(80,40),(80,51)], 5)
    return image.resize((size,size), Image.Resampling.LANCZOS)

def write(relative, size):
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    icon(size).save(target)

for size in (192,512):
    write(f"web/icons/Icon-{size}.png", size)
    write(f"web/icons/Icon-maskable-{size}.png", size)
write("web/favicon.png",32)
for density,size in {"mdpi":48,"hdpi":72,"xhdpi":96,"xxhdpi":144,"xxxhdpi":192}.items():
    write(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",size)
ios = {"20x20@1x":20,"20x20@2x":40,"20x20@3x":60,"29x29@1x":29,"29x29@2x":58,"29x29@3x":87,"40x40@1x":40,"40x40@2x":80,"40x40@3x":120,"60x60@2x":120,"60x60@3x":180,"76x76@1x":76,"76x76@2x":152,"83.5x83.5@2x":167,"1024x1024@1x":1024}
for name,size in ios.items():
    write(f"ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{name}.png",size)
icon(256).save(ROOT/"windows/runner/resources/app_icon.ico",sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
print("CryptoHub icons rendered for Android, iOS, web and Windows.")
