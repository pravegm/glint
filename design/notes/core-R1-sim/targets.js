// R5 balance targets (founder after TestFlight build 2: steeper ramp, no dead time), for speedfit.js and fix.js.
'use strict';
function target(n) {
  if (n <= 3) return null;
  if (n <= 10) return { skill: 0.3, fl: 4.0 - (0.8 / 6) * (n - 4), winMin: n >= 9 ? 0.6 : 0.75, mid: { skill: 0.6, flMin: 4.5, winMin: 1 }, parked: n === 6 };
  if (n <= 20) return { skill: 0.3, fl: 2.8 - 0.11 * (n - 11), win: 0.7 - 0.033 * (n - 11), mid: { skill: 0.6, flMin: 3.8, winMin: 0.875 }, parked: n === 11 };
  return { skill: 0.6, fl: 3.2 - 0.11 * (n - 21), winMin: 0.7, weak: { skill: 0.3, win: 0.15 - 0.011 * (n - 21) },
    strong: { skill: 0.9, winMin: 1, flMin: 4.8 }, parked: n === 21 };
}
module.exports = { target, parkedBands: [0.15, 0.25, 0.4, 0.6, 0.8] };
