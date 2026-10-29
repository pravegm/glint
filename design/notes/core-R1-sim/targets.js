// R4 balance targets (design/ROUND-4.md Core 1 + R3's parked checks), shared by speedfit.js and fix.js.
'use strict';
function target(n) {
  if (n <= 3) return null;
  if (n <= 5) return { skill: 0.3, fl: n === 4 ? 4.4 : 4.2, winMin: 1, mid: { skill: 0.6, flMin: 4.8, winMin: 1 } };
  if (n <= 10) return { skill: 0.3, fl: 4.0 - 0.1 * (n - 6), winMin: 0.8, mid: { skill: 0.6, flMin: 4.6, winMin: 1 }, parked: n === 6 };
  if (n <= 20) return { skill: 0.3, fl: 3.5 - 0.1 * (n - 11), winMin: 0.55, winMax: 0.85,
    mid: { skill: 0.6, flMin: 4.0, winMin: 1 }, parked: n === 11 };
  return { skill: 0.6, fl: 4.0 - 0.12 * (n - 21), winMin: 0.75, weak: { skill: 0.3, win: 0.35 - 0.03 * (n - 21) },
    strong: { skill: 0.9, winMin: 1, flMin: 4.75 }, parked: n === 21 };
}
module.exports = { target, parkedBands: [0.15, 0.25, 0.4, 0.6, 0.8] };
