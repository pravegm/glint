// R2 auto-tuner: per level, scale the bulk (murks and wisp flocks) until the target pilot keeps the target flowers.
// node tune.js  -> writes levels.json (read by recipes.js). Specials (brutes, splitters, hoppers, fireflies) are set
// by hand below; the tuner only sizes the crowd around them.
'use strict';
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, 'levels.json');
if (!process.env.RETUNE) { console.log('tune.js rebuilds levels.json from scratch: run with RETUNE=1'); process.exit(0); }
if (fs.existsSync(OUT)) fs.unlinkSync(OUT);
const R = require('./recipes.js');
const S = require('./sim.js');
const SEEDS = Number(process.env.SEEDS || 8);
const titles = R.levels.map(r => r.title);
// [murks0, flocks0, flockSize, brutes, splitters, hoppers, fireflies, speed, crowd, pair, front, tuneSkill, targetFlowers]
// k scales murks, flocks, brutes, splitters and hoppers together (a present kind never rounds to 0).
const base = [
  [12, 0, 0, 0, 0, 0, 0, 0.80, 1, 0, 0.0, 0, 0],
  [20, 0, 0, 1, 0, 0, 0, 0.80, 2, 0, 0.15, 0, 0],
  [24, 3, 5, 0, 0, 0, 0, 0.82, 3, 0, 0.2, 0, 0],
  [28, 4, 5, 0, 0, 0, 3, 0.84, 3, 0, 0.2, 0, 0],
  [30, 4, 5, 2, 0, 0, 3, 0.86, 3, 0, 0.2, 0, 0],
  [34, 5, 6, 2, 0, 0, 4, 0.88, 4, 0, 0.25, 0.3, 4.9],
  [36, 5, 6, 3, 0, 0, 4, 0.90, 4, 0, 0.25, 0.3, 4.8],
  [40, 6, 6, 3, 0, 0, 5, 0.91, 4, 0, 0.25, 0.3, 4.6],
  [44, 6, 6, 4, 0, 0, 5, 0.93, 4, 0, 0.25, 0.3, 4.5],
  [48, 7, 6, 4, 0, 0, 6, 0.95, 5, 0, 0.25, 0.3, 4.3],
  [44, 6, 6, 3, 2, 0, 4, 0.95, 4, 0.2, 0.3, 0.3, 4.4],
  [46, 6, 6, 3, 3, 0, 4, 0.96, 4, 0.2, 0.3, 0.3, 4.2],
  [48, 6, 6, 3, 3, 0, 5, 0.97, 5, 0.2, 0.3, 0.3, 4.0],
  [48, 6, 6, 3, 2, 2, 4, 0.98, 5, 0.2, 0.3, 0.3, 3.9],
  [50, 7, 6, 3, 3, 2, 5, 0.99, 5, 0.25, 0.3, 0.3, 3.7],
  [52, 7, 7, 4, 3, 3, 5, 1.00, 5, 0.25, 0.3, 0.3, 3.5],
  [54, 7, 7, 4, 4, 3, 5, 1.01, 5, 0.25, 0.3, 0.3, 3.4],
  [56, 8, 7, 4, 4, 3, 6, 1.02, 5, 0.3, 0.3, 0.3, 3.3],
  [58, 8, 7, 5, 4, 4, 6, 1.03, 5, 0.3, 0.3, 0.3, 3.2],
  [60, 8, 7, 5, 5, 4, 6, 1.04, 6, 0.3, 0.3, 0.3, 3.1],
  [56, 8, 7, 4, 4, 4, 4, 1.04, 5, 0.35, 0.35, 0.6, 4.3],
  [58, 8, 8, 5, 5, 4, 4, 1.06, 5, 0.35, 0.35, 0.6, 4.1],
  [60, 9, 8, 5, 5, 5, 4, 1.08, 6, 0.4, 0.35, 0.6, 3.9],
  [62, 9, 8, 6, 6, 5, 4, 1.10, 6, 0.4, 0.35, 0.6, 3.7],
  [64, 10, 8, 6, 6, 6, 4, 1.12, 6, 0.4, 0.35, 0.6, 3.5],
  [66, 10, 8, 7, 7, 6, 4, 1.14, 6, 0.45, 0.35, 0.6, 3.4],
  [68, 10, 9, 7, 7, 7, 4, 1.16, 6, 0.45, 0.35, 0.6, 3.2],
  [70, 11, 9, 8, 8, 7, 3, 1.18, 6, 0.45, 0.35, 0.6, 3.0],
  [72, 11, 9, 8, 8, 8, 3, 1.20, 6, 0.5, 0.35, 0.6, 2.8],
  [74, 12, 9, 9, 9, 8, 3, 1.22, 6, 0.5, 0.35, 0.6, 2.6],
];
const durs = [60, 60, 65, 65, 70, 70, 75, 75, 80, 85, 75, 75, 80, 80, 80, 85, 85, 90, 90, 95, 85, 85, 90, 90, 90, 95, 95, 95, 95, 95];
// R2: counts are fixed per level (below); the tuner bisects the level's SPEED, which never reshuffles the script.
function counts(i) {
  const b = base[i]; const w = Math.floor(i / 10) + 1;
  if (w === 1) return i < 5 ? [b[0], b[1], b[2], b[3], 0, 0] : [Math.round(b[0] * 1.5), b[1] + 2, b[2], b[3], 0, 0];
  if (w === 2) return [Math.round(b[0] * 0.9), b[1], Math.min(b[2], 6), b[3], b[4], b[5]];
  return [Math.round(b[0] * 0.8), b[1] - 2, 7, b[3] - 2, b[4] - 2, b[5] - 2];
}
function recipe(i, k) {
  const b = base[i]; const w = Math.floor(i / 10) + 1; const dur = durs[i]; const c = counts(i);
  const clouds = w === 1 ? 0 : w === 2 ? Math.round(dur / 30) : Math.round(dur / 19);
  return { title: titles[i], dur, murks: c[0], flocks: c[1], flockSize: c[2], brutes: c[3], splitters: c[4], hoppers: c[5],
    fireflies: b[6], speed: +(k === null ? b[7] : k).toFixed(3), crowd: b[8], pair: b[9], front: b[10],
    clouds, cloudWidth: w === 2 ? 0.07 + 0.002 * (i - 10) : 0.09 + 0.003 * (i - 20), cloudSpeed: w === 2 ? 0.06 : 0.075, cloudStrength: w === 2 ? 0.75 : 0.9 };
}
function measure(i, skill) {
  let fl = 0;
  for (let s = 0; s < SEEDS; s++) fl += S.run(S.level(i + 1), skill, 1 + s * 7919).flowers;
  return fl / SEEDS;
}
const only = process.env.LEVELS ? process.env.LEVELS.split(',').map(Number) : null;
let prev = base.map(b => b[7]);
for (let i = 0; i < 30; i++) R.levels[i] = recipe(i, prev[i]);
for (let i = 0; i < 30; i++) {
  if (only && !only.includes(i + 1)) continue;
  const b = base[i];
  if (!b[11]) { prev[i] = b[7]; R.levels[i] = recipe(i, b[7]); continue; }
  let lo = 0.6, hi = 1.5;
  for (let it = 0; it < 7; it++) {
    const k = (lo + hi) / 2; R.levels[i] = recipe(i, k);
    const f = measure(i, b[11]);
    if (f > b[12]) lo = k; else hi = k;  // faster = harder
  }
  const k = (lo + hi) / 2; prev[i] = k; R.levels[i] = recipe(i, k);
  console.log(`L${i + 1} k=${k.toFixed(2)} murks=${R.levels[i].murks} flocks=${R.levels[i].flocks} -> ${measure(i, b[11]).toFixed(2)} (target ${b[12]})`);
}
fs.writeFileSync(OUT, JSON.stringify(R.levels, null, 1));
fs.writeFileSync(OUT + '.k', JSON.stringify(prev));
