// R2 fixer: for each level, try the murk count ±3 (each re-rolls the level's script) and keep the variant whose
// pilots land closest to the R2 targets. node fix.js [LEVELS=6,7,...] -> rewrites levels.json.
'use strict';
const fs = require('fs'), path = require('path');
const R = require('./recipes.js');
const S = require('./sim.js');
const SEEDS = Number(process.env.SEEDS || 8);
const OUT = path.join(__dirname, 'levels.json');
function stats(n, skill) {
  let won = 0, fl = 0;
  for (let i = 0; i < SEEDS; i++) { const r = S.run(S.level(n), skill, 1 + i * 7919); if (r.won) won++; fl += r.flowers; }
  return { won: won / SEEDS, fl: fl / SEEDS };
}
function target(n) {
  if (n <= 5) return null;
  if (n <= 7) return { skill: 0.3, fl: 4.85, winMin: 1 };
  if (n <= 10) return { skill: 0.3, fl: 4.5, winMin: 1 };
  if (n <= 20) return { skill: 0.3, fl: 4.2 - 0.12 * (n - 11), winMin: 0.6, winMax: 0.9, mid: { skill: 0.6, flMin: 4.0, winMin: 1 } };
  return { skill: 0.6, fl: 4.1 - 0.17 * (n - 21), winMin: 0.7, weak: { skill: 0.3, winMax: 0.3 }, strong: { skill: 0.9, winMin: 1, flMin: 4.4 } };
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
  console.log(`L${n} murks ${m0}->${rec.murks} cost=${best.c.toFixed(2)} tuned=${f(best.out.a)} mid=${f(best.out.m)} weak=${f(best.out.w)} strong=${f(best.out.s)} target fl ${t.fl.toFixed(2)}`);
}
