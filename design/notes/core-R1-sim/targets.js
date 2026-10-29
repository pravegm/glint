// R3 balance targets (design/ROUND-3.md + REVIEW-2 fixes 1 and 4), shared by speedfit.js and fix.js.
'use strict';
function target(n) {
  if (n <= 5) return null;
  if (n <= 10) return { skill: 0.3, fl: [4.3, 4.0, 3.8, 3.5, 3.4][n - 6], winMin: 0.6, winMax: n >= 9 ? 0.8 : 1,
    mid: { skill: 0.6, flMin: 4.5, winMin: 1 }, parked: n === 6 };
  if (n <= 20) return { skill: 0.3, fl: 4.0 - 0.09 * (n - 11), winMin: 0.6, winMax: 0.9,
    mid: { skill: 0.6, flMin: 4.0, winMin: 1 }, parked: n === 11 };
  return { skill: 0.6, fl: 3.9 - 0.14 * (n - 21), winMin: 0.7, weak: { skill: 0.3, winMax: 0.3 },
    strong: { skill: 0.9, winMin: 1, flMin: 4.5 }, parked: n === 21 };
}
module.exports = { target, parkedBands: [0.15, 0.25, 0.4, 0.6, 0.8] };
