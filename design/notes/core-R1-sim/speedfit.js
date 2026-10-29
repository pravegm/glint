// R3: per level (LEVELS=… or 6–30), bisect the recipe speed in levels.json so the target pilot keeps the target
// flowers (targets.js). Counts and everything else stay. node speedfit.js
'use strict';
const fs = require('fs'), path = require('path');
const R = require('./recipes.js');
const S = require('./sim.js');
const { target } = require('./targets.js');
const SEEDS = Number(process.env.SEEDS || 6);
const OUT = path.join(__dirname, 'levels.json');
const only = process.env.LEVELS ? process.env.LEVELS.split(',').map(Number) : null;
function fl(n, skill) { let f = 0; for (let i = 0; i < SEEDS; i++) f += S.run(S.level(n), skill, 1 + i * 7919).flowers; return f / SEEDS; }
for (let n = 4; n <= 30; n++) {
  if (only && !only.includes(n)) continue;
  const t = target(n); const rec = R.levels[n - 1];
  let lo = 0.6, hi = 1.6;
  for (let it = 0; it < 6; it++) { rec.speed = +((lo + hi) / 2).toFixed(3); if (fl(n, t.skill) > t.fl) lo = rec.speed; else hi = rec.speed; }
  rec.speed = +((lo + hi) / 2).toFixed(3);
  fs.writeFileSync(OUT, JSON.stringify(R.levels, null, 1));
  console.log(`L${n} speed=${rec.speed} -> ${fl(n, t.skill).toFixed(2)} (target ${t.fl.toFixed(2)})`);
}
