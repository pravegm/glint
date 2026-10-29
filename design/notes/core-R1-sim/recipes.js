// title, dur, murks, flocks, flockSize, brutes, splitters, hoppers, fireflies, speed, crowd, pair
const rows = [
  ['First Light', 60, 12, 0, 0, 0, 0, 0, 0, 0.80, 1, 0],
  ['Dew', 60, 18, 0, 0, 1, 0, 0, 0, 0.85, 2, 0],
  ['Ladder of Wisps', 65, 18, 3, 4, 0, 0, 0, 0, 0.90, 2, 0],
  ['Fireflies', 65, 20, 3, 4, 0, 0, 0, 3, 0.92, 2, 0],
  ['Big Feet', 70, 20, 3, 5, 2, 0, 0, 3, 0.95, 3, 0],
  ['Clover', 70, 24, 4, 5, 2, 0, 0, 4, 0.98, 3, 0],
  ['Morning Hush', 75, 26, 4, 5, 3, 0, 0, 4, 1.01, 3, 0],
  ['Buttercups', 75, 29, 5, 5, 3, 0, 0, 5, 1.04, 3, 0],
  ['Long Shadows', 80, 31, 5, 6, 4, 0, 0, 5, 1.07, 3, 0],
  ['Meadow Sunrise', 85, 35, 6, 6, 4, 0, 0, 6, 1.10, 4, 0],
  ['Chimney Pots', 75, 32, 4, 5, 3, 6, 0, 4, 1.10, 3, 0.2],
  ['Split Ends', 75, 32, 4, 5, 3, 9, 0, 4, 1.12, 3, 0.3],
  ['Slate Grey', 80, 38, 5, 6, 4, 9, 0, 5, 1.14, 3, 0.3],
  ['Hop Along', 80, 35, 4, 6, 3, 6, 6, 4, 1.14, 3, 0.2],
  ['Gutters', 80, 41, 5, 6, 4, 9, 6, 5, 1.16, 4, 0.3],
  ['Weathervane', 85, 48, 6, 6, 5, 10, 7, 5, 1.18, 4, 0.3],
  ['Pigeon Row', 85, 50, 7, 6, 6, 11, 8, 5, 1.20, 4, 0.4],
  ['Tin Roofs', 90, 54, 7, 7, 7, 13, 9, 6, 1.22, 4, 0.4],
  ['Skylight', 90, 57, 8, 7, 7, 13, 10, 6, 1.25, 4, 0.4],
  ['Rooftop Dawn', 95, 63, 8, 7, 8, 14, 11, 6, 1.28, 5, 0.5],
  ['Low Tide', 85, 52, 7, 7, 7, 11, 8, 4, 1.20, 4, 0.4],
  ['Rope and Rigging', 85, 54, 8, 7, 8, 11, 8, 4, 1.22, 4, 0.4],
  ['Gull Cry', 90, 57, 9, 8, 8, 13, 10, 4, 1.24, 5, 0.5],
  ['Fog Bank', 90, 60, 9, 8, 9, 13, 10, 4, 1.26, 5, 0.5],
  ['Lantern Row', 90, 62, 10, 8, 9, 14, 11, 4, 1.28, 5, 0.5],
  ['Lighthouse', 95, 62, 10, 8, 9, 14, 11, 4, 1.30, 5, 0.5],
  ['Undertow', 95, 64, 11, 8, 10, 15, 13, 4, 1.32, 5, 0.6],
  ['Night Ferry', 95, 67, 11, 9, 11, 15, 13, 3, 1.34, 6, 0.6],
  ['Last Watch', 95, 70, 12, 9, 11, 17, 14, 3, 1.36, 6, 0.6],
  ['Harbour Sunrise', 95, 68, 12, 9, 10, 16, 13, 3, 1.38, 6, 0.6],
];
const W = (process.env.WS || '1,1,1').split(',').map(Number);
const fs = require('fs'), path = require('path');
const JSONFILE = path.join(__dirname, 'levels.json');
const levels = fs.existsSync(JSONFILE) && !process.env.R1 ? JSON.parse(fs.readFileSync(JSONFILE, 'utf8')) : rows.map((r, i) => { const scale = W[Math.floor(i / 10)] * (process.env.SCALE ? Number(process.env.SCALE) : 1); return ({ title: r[0], dur: r[1], murks: Math.round(r[2] * scale), flocks: r[3], flockSize: r[4], brutes: Math.round(r[5] * scale), splitters: Math.round(r[6] * scale), hoppers: Math.round(r[7] * scale), fireflies: r[8], speed: r[9], crowd: r[10], pair: r[11] }); });
const DE = (k, d) => (process.env[k] !== undefined ? Number(process.env[k]) : d);
function dailyRecipe(rng) {
  return { title: "Today's Dawn", dur: 90, murks: DE('DM', 60) + rng.int(0, 6), flocks: 6 + rng.int(0, 1), flockSize: 7, brutes: DE('DB', 5) + rng.int(0, 1), splitters: DE('DS', 4) + rng.int(0, 1), hoppers: DE('DH', 4) + rng.int(0, 1), fireflies: 5, speed: DE('DSP', 0.8), crowd: 5, pair: 0.35, front: 0.3,
    clouds: 4, cloudWidth: 0.1, cloudSpeed: 0.07, cloudStrength: 1, surfaceMin: 0.15, surfaceMax: 0.6 };
}
// R3: from wave 2 (30 s) Long Night jumps to world 2–3 pressure (k + 4), then escalates.
function endlessRecipe(n, rng) {
  const k = n === 1 ? 0 : n - 1 + DE('EJUMP', 4);
  return { murks: DE('EM', 10) + DE('EMK', 1.5) * k | 0, flocks: n >= 2 ? 1 + Math.floor(k / 2) : 0, flockSize: Math.min(4 + Math.floor(k / 3), DE('EFS', 6)),
    brutes: n >= 2 ? 1 + Math.floor(Math.max(k - 2, 0) / 3) : 0, splitters: n >= 2 ? 1 + Math.floor(Math.max(k - 3, 0) / 3) : 0, hoppers: n >= 3 ? 1 + Math.floor(Math.max(k - 4, 0) / 3) : 0,
    fireflies: n >= 2 ? (n % 2 === 1 ? 2 : 1) : 0, speed: Math.min(DE('ES0', 0.75) + DE('ESK', 0.012) * k, 1.2), crowd: Math.min(2 + Math.floor(k / 2), 6), pair: Math.min(0.08 * k, 0.5), front: 0.3,
    clouds: n >= 2 ? (n >= 9 ? 2 : 1) : 0, cloudWidth: Math.min(0.08 + 0.005 * k, 0.14), cloudSpeed: 0.07, cloudStrength: Math.min(DE('ECS0', 0.75) + 0.02 * k, 0.95),
    surfaceMin: 0.15, surfaceMax: n === 1 ? 0.35 : 0.6 };
}
module.exports = { levels, dailyRecipe, endlessRecipe };
