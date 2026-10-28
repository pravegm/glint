// Draws Glint's 1024 × 1024 app icon (opaque RGB PNG) with no dependencies: node tools/make-icon.js <out.png>
// A dawn-blue tile, a tilted brass mirror top-left throwing a gold band of light diagonally across a dark garden, and
// one cheeky shadow blob with white eyes squinting in the light. 3 × 3 supersampling for anti-aliasing.
// The in-app AppIconArt (screen=icon) is the richer version; this one exists so a build always has an icon.
'use strict';
const fs = require('fs');
const zlib = require('zlib');

const N = 1024, SS = 3;
const out = process.argv[2] || 'AppIcon-1024.png';

const mix = (a, b, t) => a + (b - a) * t;
const clamp = (x, lo = 0, hi = 1) => Math.max(lo, Math.min(hi, x));
const smooth = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
const lerpC = (c1, c2, t) => [mix(c1[0], c2[0], t), mix(c1[1], c2[1], t), mix(c1[2], c2[2], t)];
const over = (dst, src, a) => lerpC(dst, src, clamp(a));

// Band axis: from the mirror (top-left) towards the bottom-right.
const bx = 0.70, by = 0.72;            // unit direction
const bl = Math.hypot(bx, by), dx = bx / bl, dy = by / bl;
const ox = 0.30, oy = 0.30;            // band origin (mirror centre)

function shade(x, y) { // x, y in 0…1
  // Sky-to-garden background: deep indigo top, teal-blue bottom, a warm glow near the mirror.
  let c = lerpC([22, 24, 64], [10, 54, 70], y);
  const g = Math.hypot(x - 0.26, y - 0.24);
  c = over(c, [255, 170, 110], 0.55 * Math.exp(-g * g / 0.05));

  // Garden: darker grass in the lower-right two thirds, with soft dew speckle.
  const garden = smooth(0.40, 0.48, x + y * 0.9 - 0.42);
  c = over(c, [12, 60, 58], garden * 0.85);
  const speck = (Math.sin(x * 211.3 + y * 97.1) * Math.sin(x * 57.7 - y * 173.9));
  if (speck > 0.985) c = over(c, [180, 240, 230], garden * 0.5);

  // The band of light: perpendicular distance to the axis through the mirror.
  const px = x - ox, py = y - oy;
  const along = px * dx + py * dy;
  const across = Math.abs(-px * dy + py * dx);
  const width = 0.085 + along * 0.06;
  const bandA = along > 0 ? (1 - smooth(width * 0.55, width, across)) * smooth(0.0, 0.08, along) * (1 - smooth(1.05, 1.35, along)) : 0;
  c = over(c, [255, 206, 92], bandA * 0.92);
  c = over(c, [255, 244, 200], bandA * (1 - smooth(0, width * 0.45, across)) * 0.55);

  // Brass mirror: a rotated rounded rectangle around (ox, oy).
  const ang = -0.785;
  const mx = (x - ox) * Math.cos(ang) - (y - oy) * Math.sin(ang);
  const my = (x - ox) * Math.sin(ang) + (y - oy) * Math.cos(ang);
  const rw = 0.20, rh = 0.075, rr = 0.03;
  const qx = Math.abs(mx) - rw + rr, qy = Math.abs(my) - rh + rr;
  const sd = Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - rr;
  const frame = 1 - smooth(-0.002, 0.004, sd);
  const glass = 1 - smooth(-0.022, -0.016, sd);
  c = over(c, lerpC([196, 140, 60], [250, 214, 130], clamp(0.5 - my * 6)), frame);
  c = over(c, lerpC([255, 236, 196], [150, 205, 235], clamp(0.5 + mx * 2.5)), glass);
  // Glint star on the glass.
  const sx = x - 0.235, sy = y - 0.215;
  const star = Math.exp(-(sx * sx) / 0.00002 - (sy * sy) / 0.0012) + Math.exp(-(sy * sy) / 0.00002 - (sx * sx) / 0.0012);
  c = over(c, [255, 255, 255], clamp(star) * glass);

  // The shadow blob, sitting in the band's edge (bottom right), wobbly outline.
  const cx = 0.70, cy = 0.73;
  const a = Math.atan2(y - cy, x - cx);
  const r = 0.155 * (1 + 0.05 * Math.sin(a * 5 + 0.6) + 0.03 * Math.sin(a * 3 - 1.1));
  const d = Math.hypot(x - cx, (y - cy) * 1.08);
  const body = 1 - smooth(r - 0.004, r + 0.004, d);
  const rim = smooth(r - 0.03, r, d) * body * clamp(0.5 - (x - cx + y - cy) * 3); // lit from the band (top-left)
  c = over(c, [38, 18, 60], body);
  c = over(c, [255, 190, 110], rim * 0.8);
  // Eyes: white ovals squinting (flattened top) with dark pupils looking up at the light.
  for (const ex of [cx - 0.055, cx + 0.050]) {
    const ey = cy - 0.025;
    const e = Math.hypot((x - ex) / 0.040, (y - ey) / 0.032);
    const lid = smooth(ey - 0.012, ey - 0.006, y); // squint: top cut off
    const white = (1 - smooth(0.92, 1.02, e)) * lid;
    c = over(c, [250, 248, 255], white);
    const pe = Math.hypot((x - ex + 0.008) / 0.016, (y - ey + 0.004) / 0.016);
    c = over(c, [20, 10, 30], (1 - smooth(0.85, 1.05, pe)) * white);
  }
  // Sparks popping off the blob's lit side.
  for (const [sx2, sy2, s] of [[0.53, 0.58, 0.012], [0.58, 0.53, 0.008], [0.50, 0.66, 0.007]]) {
    const dd = Math.hypot(x - sx2, y - sy2);
    c = over(c, [255, 236, 160], 1 - smooth(s * 0.4, s, dd));
  }
  return c;
}

const raw = Buffer.alloc(N * (N * 3 + 1));
for (let j = 0; j < N; j++) {
  raw[j * (N * 3 + 1)] = 0;
  for (let i = 0; i < N; i++) {
    let r = 0, g = 0, b = 0;
    for (let sj = 0; sj < SS; sj++) for (let si = 0; si < SS; si++) {
      const c = shade((i + (si + 0.5) / SS) / N, (j + (sj + 0.5) / SS) / N);
      r += c[0]; g += c[1]; b += c[2];
    }
    const k = j * (N * 3 + 1) + 1 + i * 3;
    raw[k] = Math.round(clamp(r / (SS * SS), 0, 255));
    raw[k + 1] = Math.round(clamp(g / (SS * SS), 0, 255));
    raw[k + 2] = Math.round(clamp(b / (SS * SS), 0, 255));
  }
}

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(N, 0); ihdr.writeUInt32BE(N, 4);
ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0; // 8-bit RGB
const png = Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
]);
fs.writeFileSync(out, png);
console.log(`wrote ${out} (${png.length} bytes)`);
