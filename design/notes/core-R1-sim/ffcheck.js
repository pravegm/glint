const S = require('./sim.js');
const lv = (process.env.LV || '4,8,16,20,24').split(',').map(Number);
const out = [];
for (const sk of [0.6, 0.9]) { let fz = 0, fl = 0, n = 0; for (const L of lv) for (let i = 0; i < 4; i++) { const r = S.run(S.level(L), sk, 1 + i * 7919); fz += r.scorched; fl += r.flowers; n++; } out.push(sk + ': fz/level=' + (fz / lv.length / 4).toFixed(2) + ' fl=' + (fl / n).toFixed(2)); }
console.log(out.join(' | '));
