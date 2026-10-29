// R5: the longest empty-field stretch (no gloom on the field, submerged ones count) per level, 0.9 pilot (it clears
// the field fastest), and the first surfacing after the first light.
const S = require('./sim.js');
let worst = 0; const parts = [];
for (let n = 1; n <= 30; n++) {
  let me = 0, first = 0;
  for (let i = 0; i < 3; i++) {
    const r = S.run(S.level(n), 0.9, 1 + i * 7919); me = Math.max(me, r.maxEmpty);
    const s = new S.Session(S.level(n), 1 + i * 7919, false); let t = 0, f = null; while (t < 3 && f === null) { for (const e of s.step(1 / 60, { band: 0.3, isShut: false })) if (e[0] === 'surfaced' && f === null) f = s.time; t += 1 / 60; } first = Math.max(first, f === null ? 9 : f);
  }
  worst = Math.max(worst, me); parts.push(`L${n} empty=${me.toFixed(1)} first=${first.toFixed(2)}`);
}
console.log(parts.join(' | ')); console.log('worst empty', worst.toFixed(2));
