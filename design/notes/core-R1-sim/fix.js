// R2/R3 fixer: for each level, try the murk count ±3 (each re-rolls the level's script) and keep the variant whose
// pilots land closest to the targets (targets.js), including R3's parked-band check on L6/L11/L21.
// node fix.js [LEVELS=6,7,...] -> rewrites levels.json.
'use strict';
const fs = require('fs'), path = require('path');
const R = require('./recipes.js');
const S = require('./sim.js');
const { target, parkedBands } = require('./targets.js');
const SEEDS = Number(process.env.SEEDS || 8);
const OUT = path.join(__dirname, 'levels.json');
function stats(n, skill) {
  let won = 0, fl = 0;
  for (let i = 0; i < SEEDS; i++) { const r = S.run(S.level(n), skill, 1 + i * 7919); if (r.won) won++; fl += r.flowers; }
  return { won: won / SEEDS, fl: fl / SEEDS };
}
function parkedWorst(n) {
  // the best any parked band does: lowest flowers lost (L6/L11 need >= 2) and whether any band wins (L21 must not)
  let minLost = 9, anyWin = false;
  for (const b of parkedBands) for (let i = 0; i < 3; i++) {
    const r = S.run(S.level(n), 0, 1 + i * 7919, false, 200, undefined, b);
    minLost = Math.min(minLost, 5 - r.flowers); if (r.won) anyWin = true;
  }
  return { minLost, anyWin };
}
function cost(n, t) {
  const a = stats(n, t.skill);
  let c = Math.abs(a.fl - t.fl);
  if (a.won < t.winMin) c += 3 * (t.winMin - a.won);
  if (t.winMax !== undefined && a.won > t.winMax) c += 1.5 * (a.won - t.winMax);
  const out = { a };
  if (t.mid) { const m = stats(n, t.mid.skill); out.m = m; if (m.won < t.mid.winMin) c += 3; if (m.fl < t.mid.flMin) c += t.mid.flMin - m.fl; }
  if (t.weak) { const w = stats(n, t.weak.skill); out.w = w; if (w.won > t.weak.winMax) c += 2 * (w.won - t.weak.winMax); }
  if (t.strong) { const s = stats(n, t.strong.skill); out.s = s; if (s.won < t.strong.winMin) c += 5; if (s.fl < t.strong.flMin) c += 2 * (t.strong.flMin - s.fl); }
  if (t.parked) {
    const p = parkedWorst(n); out.p = p;
    if (n === 21) { if (p.anyWin) c += 10; } else if (p.minLost < 2) c += 10;
  }
  return { c, out };
}
const only = process.env.LEVELS ? process.env.LEVELS.split(',').map(Number) : null;
for (let n = 6; n <= 30; n++) {
  if (only && !only.includes(n)) continue;
  const t = target(n); const rec = R.levels[n - 1]; const m0 = rec.murks;
  let best = null;
  for (let d = -3; d <= 3; d++) {
    rec.murks = m0 + d;
    const r = cost(n, t);
    if (!best || r.c < best.c) best = { c: r.c, d, out: r.out };
  }
  rec.murks = m0 + best.d;
  fs.writeFileSync(OUT, JSON.stringify(R.levels, null, 1));
  const f = (x) => x ? `${(x.won * SEEDS).toFixed(0)}/${SEEDS} ${x.fl.toFixed(2)}` : '-';
  const p = best.out.p ? ` parked minLost=${best.out.p.minLost} anyWin=${best.out.p.anyWin}` : '';
  console.log(`L${n} murks ${m0}->${rec.murks} cost=${best.c.toFixed(2)} tuned=${f(best.out.a)} mid=${f(best.out.m)} weak=${f(best.out.w)} strong=${f(best.out.s)}${p} target fl ${t.fl.toFixed(2)}`);
}
