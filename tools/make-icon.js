// Draws Glint's 1024 × 1024 app icon (opaque RGB PNG) with no dependencies: node tools/make-icon.js <out.png>
// R3: a round brass hand mirror catches the sun and throws a soft beam onto one squinting shadow blob.
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

// R3 (REVIEW-2 fix 8): a round brass hand mirror catching the sun (top right) and throwing a soft beam down onto
// one squinting shadow (bottom right). One smooth gradient background, no hard edges, readable at 60 px.
const SUN = [0.78, 0.20], SUN_R = 0.115;
const MIR = [0.36, 0.40], MIR_R = 0.185;
const GL = [0.66, 0.76];
function shade(x, y) {
  // Background: deep indigo at the top, warm dusk violet, then teal garden at the bottom, all smooth.
  let c = lerpC([24, 22, 70], [92, 46, 104], smooth(0.0, 0.62, y));
  c = lerpC(c, [14, 66, 72], smooth(0.55, 1.0, y));
  // Sun glow and disc.
  const ds = Math.hypot(x - SUN[0], y - SUN[1]);
  c = over(c, [255, 170, 96], 0.75 * Math.exp(-ds * ds / 0.035));
  c = over(c, lerpC([255, 236, 150], [255, 150, 60], clamp((y - SUN[1] + SUN_R) / (2 * SUN_R))),
    1 - smooth(SUN_R - 0.004, SUN_R + 0.004, ds));
  // The beam: a soft cone from the mirror towards the gloom (additive warm light, feathered edges).
  const vx = GL[0] - MIR[0], vy = GL[1] - MIR[1], vl = Math.hypot(vx, vy), ux = vx / vl, uy = vy / vl;
  const px = x - MIR[0], py = y - MIR[1];
  const along = px * ux + py * uy, across = Math.abs(-px * uy + py * ux);
  if (along > 0) {
    const w = 0.07 + along * 0.22;
    const a = (1 - smooth(w * 0.35, w, across)) * smooth(0.02, 0.18, along) * (1 - smooth(vl * 1.05, vl * 1.45, along));
    c = [Math.min(255, c[0] + 220 * a), Math.min(255, c[1] + 175 * a), Math.min(255, c[2] + 40 * a)];
  }
  // A pool of light on the ground under the gloom.
  const pd = Math.hypot((x - GL[0]) / 1.6, (y - GL[1] - 0.10) / 0.7);
  const pool = Math.exp(-pd * pd / 0.012) * 0.6;
  c = [Math.min(255, c[0] + 180 * pool), Math.min(255, c[1] + 140 * pool), Math.min(255, c[2] + 60 * pool)];
  // The mirror: handle (behind), a thick brass rim, then the glass reflecting the sun.
  // Mirror frame in its own tilted, oval space (rotated -24°, 1.28 taller than wide).
  const ca = Math.cos(-0.42), sa = Math.sin(-0.42);
  const lx = (x - MIR[0]) * ca - (y - MIR[1]) * sa, ly = (x - MIR[0]) * sa + (y - MIR[1]) * ca;
  // Handle: short and stout, with a collar and a round knob.
  const hy0 = MIR_R * 1.28 - 0.01;
  const hw = 0.034 + 0.010 * Math.sin(clamp((ly - hy0) / 0.16) * Math.PI * 2.2);
  const handle = (1 - smooth(hw - 0.004, hw + 0.002, Math.abs(lx))) * smooth(hy0 - 0.01, hy0, ly) * (1 - smooth(hy0 + 0.15, hy0 + 0.16, ly));
  const knob = 1 - smooth(0.040, 0.046, Math.hypot(lx, ly - (hy0 + 0.17)));
  c = over(c, lerpC([140, 88, 36], [240, 196, 110], clamp(0.55 - lx * 10)), Math.max(handle, knob));
  const dm = Math.hypot(lx, ly / 1.28);
  const theta = Math.atan2(ly / 1.28, lx);
  const scallop = MIR_R + 0.010 * Math.cos(theta * 14);
  const rim = 1 - smooth(scallop - 0.004, scallop + 0.003, dm);
  const rimShade = clamp(0.5 + (lx * -0.7 + ly * -0.5) * 4);
  c = over(c, lerpC([160, 102, 40], [255, 224, 142], rimShade), rim);
  // An inner groove line on the brass.
  c = over(c, [120, 72, 28], (1 - smooth(0.0025, 0.006, Math.abs(dm - (MIR_R - 0.022)))) * 0.8);
  const gr = MIR_R - 0.032;
  const glass = 1 - smooth(gr - 0.003, gr + 0.003, dm);
  // Reflection: sky, with the image of the sun towards the upper right of the glass.
  let g = lerpC([255, 232, 190], [150, 120, 190], clamp((ly + gr * 1.28) / (2 * gr * 1.28)));
  const ri = Math.hypot(lx - 0.045, ly + 0.07);
  g = over(g, [255, 200, 100], 0.7 * Math.exp(-ri * ri / 0.006));
  g = over(g, [255, 240, 170], 1 - smooth(0.040, 0.050, ri));
  g = over(g, [255, 255, 255], 0.30 * (1 - smooth(0.0, 0.018, Math.abs(lx + ly * 0.7 + 0.05))));
  c = over(c, g, glass);
  // Glint: a small 4-point sparkle on the glass edge.
  const sx = x - (MIR[0] + 0.085), sy = y - (MIR[1] - 0.095);
  const star = Math.exp(-(sx * sx) / 0.00003 - (sy * sy) / 0.0016) + Math.exp(-(sy * sy) / 0.00003 - (sx * sx) / 0.0016);
  c = over(c, [255, 255, 255], clamp(star));
  // The gloom: wobbly inky blob, rim-lit from the beam side, squinting.
  const cx = GL[0], cy = GL[1];
  const an = Math.atan2(y - cy, x - cx);
  const r = 0.16 * (1 + 0.045 * Math.sin(an * 5 + 0.6) + 0.03 * Math.sin(an * 3 - 1.1));
  const d = Math.hypot(x - cx, (y - cy) * 1.1);
  const body = 1 - smooth(r - 0.004, r + 0.004, d);
  const lit = clamp(0.5 - ((x - cx) * ux + (y - cy) * uy) * 5);
  c = over(c, lerpC([34, 16, 56], [70, 34, 92], clamp(0.5 - (y - cy) * 3)), body);
  c = over(c, [255, 196, 120], smooth(r - 0.035, r - 0.002, d) * body * lit * 0.9);
  for (const ex of [cx - 0.055, cx + 0.052]) {
    const ey = cy - 0.02;
    const e = Math.hypot((x - ex) / 0.042, (y - ey) / 0.034);
    const lid = smooth(ey - 0.010, ey - 0.003, y);
    const white = (1 - smooth(0.92, 1.03, e)) * lid;
    c = over(c, [252, 250, 255], white);
    const pe = Math.hypot((x - ex + 0.012) / 0.017, (y - ey + 0.002) / 0.017);
    c = over(c, [22, 10, 32], (1 - smooth(0.85, 1.05, pe)) * white);
    // Heavy brow on the squint, slanting down towards the middle.
    const slope = ex < cx ? -0.28 : 0.28;
    const brow = (1 - smooth(0.004, 0.009, Math.abs(y - (ey - 0.011 - (x - ex) * slope)))) * (1 - smooth(0.04, 0.05, Math.abs(x - ex)));
    c = over(c, [18, 8, 28], brow);
  }
  // A small grimace.
  const mx = x - cx, my = y - (cy + 0.055);
  const mouth = (1 - smooth(0.004, 0.009, Math.abs(my - mx * mx * 6))) * (1 - smooth(0.03, 0.04, Math.abs(mx)));
  c = over(c, [250, 240, 250], mouth * 0.9);
  // Sparks where the light hits.
  for (const [sx2, sy2, s2] of [[0.52, 0.62, 0.012], [0.57, 0.56, 0.008], [0.49, 0.70, 0.007], [0.80, 0.62, 0.009]]) {
    const dd = Math.hypot(x - sx2, y - sy2);
    c = over(c, [255, 240, 170], 1 - smooth(s2 * 0.4, s2, dd));
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
