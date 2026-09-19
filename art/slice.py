# Slice the 3x2 sprite sheet into 6 poses on one shared canvas, wrist bottom-centered, then trace to SVG.
from PIL import Image
import vtracer, os
NAMES = ['fist', 'rock', 'paper', 'scissors', 'smear_open', 'smear_v']
sheet = Image.open('sheet.png').convert('RGBA')
W, H = sheet.size
cw, ch = W // 3, H // 2
crops = []
for i, n in enumerate(NAMES):
    c = sheet.crop(((i % 3) * cw, (i // 3) * ch, (i % 3 + 1) * cw, (i // 3 + 1) * ch))
    a = c.getchannel('A').point(lambda v: 255 if v > 24 else 0)
    crops.append((n, c.crop(a.getbbox())))
bw = max(c.width for _, c in crops) + 8
bh = max(c.height for _, c in crops) + 8
os.makedirs('png', exist_ok=True)
out = '../app/assets/hands'
os.makedirs(out, exist_ok=True)
for n, c in crops:
    canvas = Image.new('RGBA', (bw, bh), (0, 0, 0, 0))
    canvas.paste(c, ((bw - c.width) // 2, bh - c.height - 4), c)
    # alpha-0 pixels keep junk RGB; zero them and harden edges so tracing stays clean
    px = canvas.load()
    for y in range(bh):
        for x in range(bw):
            r, g, b, al = px[x, y]
            px[x, y] = (0, 0, 0, 0) if al < 128 else (r, g, b, 255)
    canvas.save(f'png/{n}.png')
    vtracer.convert_image_to_svg_py(f'png/{n}.png', f'{out}/{n}.svg', colormode='color',
        hierarchical='stacked', mode='spline', filter_speckle=6, color_precision=5,
        layer_difference=24, corner_threshold=60, length_threshold=4.0, splice_threshold=45, path_precision=2)
    print(n, c.size, os.path.getsize(f'{out}/{n}.svg') // 1024, 'KB')
print('canvas', bw, bh)
