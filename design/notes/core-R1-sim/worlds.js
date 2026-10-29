// R4: the per-world summary BalanceTests prints (GLINT-BAL world=...), from the mirror.
const S = require('./sim.js');
const seeds = Number(process.env.SEEDS || 8);
for (let w = 1; w <= 3; w++) for (const sk of [0.3, 0.6, 0.9]) {
  let won = 0, fl = 0, three = 0, fz = 0, n = 0;
  for (let L = w * 10 - 9; L <= w * 10; L++) { const spec = S.level(L); for (let i = 0; i < seeds; i++) { const r = S.run(spec, sk, 1 + i * 7919); n++; if (r.won) won++; fl += r.flowers; fz += r.scorched; if (r.won && r.flowers === 5 && r.score >= (spec.starScore || 0)) three++; } }
  console.log(`GLINT-BAL world=${w} skill=${sk} winrate=${(won / n).toFixed(2)} flowers=${(fl / n).toFixed(2)} three=${(three / n).toFixed(2)} scorched=${(fz / (n)).toFixed(2)}`);
}
