// R3: each level's starScore (3rd star = 5 flowers AND score >= starScore), set so the 0.6 pilot makes it ~60 % of
// the time and the 0.9 pilot ~95 % (the lower of the two bars, rounded down to 50). node starscore.js -> levels.json
'use strict';
const fs = require('fs'), path = require('path');
const R = require('./recipes.js');
const S = require('./sim.js');
const SEEDS = Number(process.env.SEEDS || 12);
const OUT = path.join(__dirname, 'levels.json');
function scores(n, skill) { const out = []; for (let i = 0; i < SEEDS; i++) { const r = S.run(S.level(n), skill, 1 + i * 7919); out.push(r.flowers === 5 ? r.score : -1); } return out; }
// the bar that `share` of all runs clear with 5 flowers (or the lowest 5-flower score if fewer clear it)
function bar(list, share) {
  const ok = list.filter(x => x >= 0).sort((a, b) => b - a);
  if (ok.length === 0) return Infinity;
  const want = Math.max(1, Math.round(share * list.length));
  return ok[Math.min(want, ok.length) - 1];
}
for (let n = 1; n <= 30; n++) {
  // R4: L1–3 the weak hand's median 5-flower score + 50 (0.3 makes 3★ ≤ 50 %); later the 0.6 bar (~60 %) capped by
  // the 0.9 bar (~90 %; Harbour ~75 %, so 0.9 makes 3★ on ≥ 70 %).
  const a = bar(scores(n, 0.6), 0.6), b = bar(scores(n, 0.9), n > 20 ? 0.75 : 0.9);
  const w = bar(scores(n, 0.3), 0.5);
  const s = n <= 3 ? Math.ceil((w + 1) / 50) * 50 : Math.floor(Math.min(a, b) / 50) * 50;
  R.levels[n - 1].starScore = Number.isFinite(s) ? s : 0;
  fs.writeFileSync(OUT, JSON.stringify(R.levels, null, 1));
  console.log(`L${n} starScore=${R.levels[n - 1].starScore} (0.6 bar ${a}, 0.9 bar ${b})`);
}
