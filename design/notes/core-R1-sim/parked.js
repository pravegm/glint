// R3: a parked band (any fixed d) must lose >= 2 flowers on L6 and L11 and fail L21.
const S = require('./sim.js');
const lv = (process.env.LV || '6,11,21').split(',').map(Number);
const seeds = Number(process.env.SEEDS || 3);
for (const n of lv) {
  const parts = [];
  for (const b of [0.15, 0.25, 0.4, 0.6, 0.8]) {
    let lost = 0, won = 0;
    for (let i = 0; i < seeds; i++) { const r = S.run(S.level(n), 0, 1 + i * 7919, false, 200, undefined, b); lost += 5 - r.flowers; if (r.won) won++; }
    parts.push(`b${b}: lost=${(lost / seeds).toFixed(1)} won=${won}/${seeds}`);
  }
  console.log('L' + n, parts.join(' | '));
}
