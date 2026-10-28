const S = require('./sim.js');
const lv = (process.env.LV || '11').split(',').map(Number), sk = Number(process.env.SK || 0.3);
for (const n of lv) {
  const by = {}; let ff = 0;
  for (let i = 0; i < 6; i++) {
    const s = new S.Session(S.level(n), 1 + i * 7919, false); const p = new S.Pilot(sk, (1 + i * 7919) * 7 + 1);
    let t = 0; while (!s.finished && t < 120) { const ev = s.step(1 / 60, { band: p.band_(s.snapshot(), 1 / 60), isShut: false }); for (const e of ev) { if (e[0] === 'eaten') by[e[3] + (e[3] === 'wisp' ? '' : '')] = (by[e[3]] || 0) + 1; if (e[0] === 'scorched') ff++; } t += 1 / 60; }
  }
  console.log('L' + n, 'eaten by', JSON.stringify(by), 'scorched', ff);
}
