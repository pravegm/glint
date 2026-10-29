// Glint Core R1 JS mirror (tuning only; the Swift in Glint/Core is the truth). Run: node sim.js  (env SEEDS, SKILLS, LEVELS, EXTRA=1)
'use strict';
const M64 = (1n << 64n) - 1n;
class RNG {
  constructor(seed) { this.s = BigInt.asUintN(64, BigInt(seed)); }
  next() {
    this.s = (this.s + 0x9E3779B97F4A7C15n) & M64;
    let z = this.s;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & M64;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & M64;
    return z ^ (z >> 31n);
  }
  unit() { return Number(this.next() >> 11n) * (1.0 / 9007199254740992.0); }
  range(a, b) { return a + (b - a) * this.unit(); }
  int(a, b) { if (b <= a) return a; const span = BigInt(b - a) + 1n; return a + Number(this.next() % span); }
}

const T = {
  bandMin: -0.2, core: Number(process.env.CORE || 0.065), edge: Number(process.env.EDGE || 0.10), submergedSpeed: 1.6, flowerCount: 5, chainWindow: 1.6, sweepWindow: 0.35, maxMult: 4,
  chainStep: 0.25, sweepMin: 3, sweepPer: 30, flowerBonus: 40, pad: 0.4, burn: 1.0,
  ffSpeed: 0.075, ffRadius: 0.02, ffScorch: 0.35, ffDecay: 0.6, ffBloom: 50, ffWaveAmp: 0.06, ffWaveHz: 0.35,
  splitCount: 2, splitFling: 0.07, splitFlingSpeed: 0.30, splitFlingTime: 0.6, splitSpreadU: 0.06,
  hopRest: 0.9, hopDist: 0.14, hopTime: 0.22, hopHurry: Number(process.env.HURRY || 1.0),
  creaseShade: Number(process.env.SHADE || 0.12), cloudEdge: 0.03, substep: 1 / 120, endlessWave: 30, endlessSun: 600, dailyDuration: 90,
};
function smooth(t) { t = Math.min(Math.max(t, 0), 1); return t * t * (3 - 2 * t); }
function intensityDist(dist) {
  if (dist <= T.core) return 1;
  if (dist >= T.edge) return 0;
  return smooth((T.edge - dist) / (T.edge - T.core));
}
const SPEC = {
  murk: { hp: 0.55, speed: 0.10, r: 0.050, pts: 10 },
  wisp: { hp: 0.12, speed: 0.21, r: 0.030, pts: 5 },
  brute: { hp: Number(process.env.BRUTE_HP || 4.5), speed: 0.065, r: 0.085, pts: 40 },
  splitter: { hp: 0.7, speed: 0.09, r: 0.060, pts: 15 },
  hopper: { hp: 0.8, speed: 0.14 / (0.9 + 0.22), r: 0.050, pts: 20 },
};

// ---------------- LevelBook ----------------
// recipe: [title, dur, murks, flocks, flockSize, brutes, splitters, hoppers, fireflies, speed, crowd]
const R = require('./recipes.js');
function levelSeed(n) { return (0x474C494E54n * 1000n + BigInt(n) * 7919n); }
const COST = { murk: 0.55, wisp: 0.22, brute: 3.0, splitter: 1.3, hopper: 1.3, firefly: 0.7 };
const BIAS = { murk: 0, wisp: 0.1, brute: 0.3, splitter: 0.15, hopper: 0.2, firefly: 0.1 };
function build(rec, rng, start, span, endPad) {
  const items = [];
  const S = rec.speed;
  function uRange(w) { const c = rng.range(0.1 + w / 2, 0.9 - w / 2); return [c - w / 2, c + w / 2]; }
  let left = rec.murks;
  while (left > 0) {
    const k = Math.min(left, rng.int(1, rec.crowd)); left -= k;
    const line = k >= 3 && rng.unit() < 0.4;
    items.push({ kind: 'murk', count: k, u: uRange(k === 1 ? 0.2 : 0.5), form: line ? 'line' : 'cluster' });
  }
  for (let i = 0; i < rec.flocks; i++) items.push({ kind: 'wisp', count: rec.flockSize, u: uRange(0.6), form: rng.unit() < 0.5 ? 0.16 : 'cluster' });
  for (let i = 0; i < rec.brutes; i++) items.push({ kind: 'brute', count: 1, u: uRange(0.3), form: 'cluster' });
  for (let i = 0; i < rec.splitters; i++) items.push({ kind: 'splitter', count: rng.unit() < rec.pair ? 2 : 1, u: uRange(0.5), form: 'line' });
  for (let i = 0; i < rec.hoppers; i++) items.push({ kind: 'hopper', count: rng.unit() < rec.pair ? 2 : 1, u: uRange(0.5), form: 'line' });
  for (let i = 0; i < rec.fireflies; i++) items.push({ kind: 'firefly', count: 1, u: uRange(0.4), form: 'cluster' });
  // R3: where each group surfaces (rec.surfaceMax 0 = never submerged).
  const smax = rec.surfaceMax || 0, smin = rec.surfaceMin || 0.15;
  const HI = { murk: smax, wisp: Math.min(0.55, smax), brute: Math.min(0.3, smax), splitter: Math.min(0.45, smax), hopper: Math.min(0.4, smax) };
  for (const it of items) {
    if (smax <= 0 || it.kind === 'firefly') { it.surf = [0, 0]; continue; }
    const hi = Math.max(HI[it.kind], smin);
    if (it.kind === 'murk' && it.form === 'cluster' && it.count >= 2) {
      const c = rng.range(smin + 0.05, Math.max(hi - 0.05, smin + 0.05)); it.surf = [c - 0.05, c + 0.05];
    } else { const v = rng.range(smin, hi); it.surf = [v, v]; }
  }
  for (const it of items) it.key = rng.unit() * (1 - BIAS[it.kind]) + BIAS[it.kind];
  items.sort((x, y) => x.key - y.key);
  let total = 0; for (const it of items) total += COST[it.kind] * it.count;
  const t1 = span - endPad; let cum = 0;
  const g = [];
  for (const it of items) {
    const c = COST[it.kind] * it.count; const mid = (cum + c / 2) / Math.max(total, 1e-9); cum += c;
    const join = g.length > 0 ? rng.unit() < (rec.front || 0) && it.kind !== 'brute' && g[g.length - 1].kind !== 'brute' : false;
    // density 0.6 + 0.8x: F(x) = 0.6x + 0.4x^2  ->  x = (-0.6 + sqrt(0.36 + 1.6F)) / 0.8
    const x = join ? g[g.length - 1].x : (-0.7 + Math.sqrt(0.49 + 1.2 * mid)) / 0.6;
    const t = join ? g[g.length - 1].time : start + t1 * x;
    g.push({ x, time: t, kind: it.kind, count: it.count, u: it.u, form: it.form, surf: it.surf, s: it.kind === 'firefly' ? 1 : S * (0.95 + 0.1 * x) });
  }
  return g;
}
// R2 cloud shadows: rec.clouds of them, evenly through the level with jitter, each sliding in from an edge.
function cloudsFor(rec, rng, start, span) {
  const out = []; const n = rec.clouds || 0;
  const a = start + 6, b = Math.max(start + span - 16, a);
  for (let i = 0; i < n; i++) {
    let x = (i + 0.5 + rng.range(-0.3, 0.3)) / n; x = Math.min(Math.max(x, 0), 1);
    const fromLeft = rng.unit() < 0.5;
    const hw = rec.cloudWidth * (0.8 + 0.4 * rng.unit());
    const speed = rec.cloudSpeed * (0.8 + 0.4 * rng.unit());
    out.push({ time: a + (b - a) * x, fromLeft, halfWidth: hw, speed, strength: rec.cloudStrength || 1 });
  }
  return out;
}
function cloudFactor(u, shades) {
  let f = 1;
  for (const c of shades) {
    const dist = Math.abs(u - c.u);
    const e = smooth((c.hw + T.cloudEdge / 2 - dist) / T.cloudEdge);
    f *= 1 - c.strength * e;
  }
  return f;
}
function level(n) {
  n = Math.min(Math.max(n, 1), 30);
  const rec = R.levels[n - 1];
  const rng = new RNG(levelSeed(n));
  const groups = build(rec, rng, 2.5, rec.dur - 2.5, 8);
  return { number: n, world: Math.floor((n - 1) / 10) + 1, title: rec.title, duration: rec.dur, groups, clouds: cloudsFor(rec, rng, 2.5, rec.dur - 2.5), starScore: rec.starScore || 0 };
}
function daily(day) {
  const rng = new RNG(dailySeed(day) ^ 0x5A5A5A5An);
  const rec = R.dailyRecipe(rng);
  const groups = build(rec, rng, 2.5, 87.5, 8);
  return { number: 0, world: 2, title: "Today's Dawn", duration: 90, groups, clouds: cloudsFor(rec, rng, 2.5, 87.5) };
}
function dailySeed(day) { const r = new RNG(0x474C494E54000000n ^ BigInt.asUintN(64, BigInt(day))); return r.next(); }

// ---------------- Session ----------------
class Session {
  constructor(spec, seed, endless) {
    this.rng = new RNG(seed);
    this.spec = spec; this.endless = !!endless;
    this.duration = spec ? spec.duration : 0;
    this.phase = 'waiting'; this.time = 0; this.glooms = []; this.ffs = []; this.flowers = [true, true, true, true, true];
    this.score = 0; this.chain = 0; this.lastPop = -1e9; this.sweep = 0; this.pops = 0; this.nextId = 1;
    this.queue = []; this.qi = 0; this.seq = 0; this.firstBand = null; this.band = T.bandMin; this.wave = 0;
    this.eaten = 0; this.scorched = 0; this.delivered = 0; this.longestChain = 0;
    this.cloudQ = []; this.ci = 0; this.shades = []; this.blockedCloud = 0; this.blockedCrease = 0; this.blockedSub = 0; this.surfacedN = 0;
    if (spec) { this.expand(spec.groups, 0); this.addClouds(spec.clouds || [], 0); }
  }
  addClouds(list, offset) {
    for (const c of list) this.cloudQ.push(Object.assign({}, c, { time: c.time + offset }));
    const rest = this.cloudQ.slice(this.ci); rest.sort((a, b) => a.time - b.time); this.cloudQ = rest; this.ci = 0;
  }
  expand(groups, offset) {
    for (const gr of groups) {
      for (let i = 0; i < gr.count; i++) {
        let t = gr.time + offset, u;
        if (gr.form === 'cluster') u = this.rng.range(gr.u[0], gr.u[1]);
        else if (gr.form === 'line') u = gr.u[0] + (gr.u[1] - gr.u[0]) * (i + 0.5) / gr.count;
        else { u = gr.u[0] + (gr.u[1] - gr.u[0]) * (gr.count > 1 ? i / (gr.count - 1) : 0.5); t += gr.form * i; }
        const phase = this.rng.unit();
        const sf = gr.surf || [0, 0];
        const sd = gr.kind === 'firefly' ? 0 : sf[0] + (sf[1] - sf[0]) * this.rng.unit();
        this.queue.push({ seq: this.seq++, t, kind: gr.kind, u: Math.min(Math.max(u, 0.03), 0.97), s: gr.s, phase, sd });
      }
    }
    const rest = this.queue.slice(this.qi); rest.sort((a, b) => a.t - b.t || a.seq - b.seq); this.queue = rest; this.qi = 0;
  }
  get finished() { return this.phase === 'won' || this.phase === 'lost'; }
  step(dt, inp) {
    if (dt <= 0 || this.finished) return [];
    const ev = [];
    const b = Math.min(Math.max(inp.band, T.bandMin), 1);
    if (this.phase === 'waiting') {
      if (this.firstBand === null) this.firstBand = b;
      if (!inp.isShut && (b >= 0 || Math.abs(b - this.firstBand) > 0.02)) { this.phase = 'playing'; ev.push(['started']); if (this.endless) this.startWave(ev); }
      else { this.band = b; return ev; }
    }
    const n = Math.max(1, Math.ceil(dt / T.substep - 1e-9)); const h = dt / n;
    const b0 = this.band;
    for (let k = 1; k <= n && !this.finished; k++) {
      const bb = b0 + (b - b0) * k / n;
      this.sub(h, bb, !inp.isShut, ev);
    }
    this.band = b;
    return ev;
  }
  startWave(ev) {
    this.wave += 1;
    if (this.wave > 1) ev.push(['waveUp', this.wave]);
    const rec = R.endlessRecipe(this.wave, this.rng);
    this.expand(build(rec, this.rng, 0, 30, 0), this.time);
    this.addClouds(cloudsFor(rec, this.rng, 0, 30), this.time);
  }
  sub(h, b, on, ev) {
    this.time += h;
    const now = this.time;
    if (this.endless && now >= this.wave * T.endlessWave) this.startWave(ev);
    while (this.qi < this.queue.length && this.queue[this.qi].t <= now) {
      const e = this.queue[this.qi++];
      if (e.kind === 'firefly') {
        this.ffs.push({ id: this.nextId++, u: e.u, baseU: e.u, d: -T.ffRadius, scorch: 0, lit: 0, age: 0, speed: T.ffSpeed * e.s, phase: e.phase });
      } else this.spawn(e.kind, e.u, null, e.s, false, e.sd, ev);
    }
    while (this.ci < this.cloudQ.length && this.cloudQ[this.ci].time <= now) {
      const c = this.cloudQ[this.ci++];
      this.shades.push({ id: this.nextId++, u: c.fromLeft ? -c.halfWidth : 1 + c.halfWidth, hw: c.halfWidth, dir: c.fromLeft ? 1 : -1, speed: c.speed, strength: c.strength });
    }
    if (this.shades.length) {
      let k = 0;
      for (const c of this.shades) { c.u += c.dir * c.speed * h; if (!(c.dir > 0 ? c.u - c.hw > 1.02 : c.u + c.hw < -0.02)) this.shades[k++] = c; }
      this.shades.length = k;
    }
    const kids = [];
    let w = 0;
    for (let r = 0; r < this.glooms.length; r++) {
      const g = this.glooms[r];
      const dist = Math.max(0, Math.abs(g.d - b) - T.pad * g.r);
      const raw = on ? intensityDist(dist) : 0;
      const cf = this.shades.length ? cloudFactor(g.u, this.shades) : 1;
      if (g.sub) {
        if (raw > 0) this.blockedSub += raw * h;
        g.lit = 0; g.wasLit = false; g.age += h; g.tension = 0;
        g.d += g.speed * T.submergedSpeed * h;
        if (g.d >= g.sd) { g.sub = false; this.surfacedN++; ev.push(['surfaced', g.kind, g.d]); }
        this.glooms[w++] = g; continue;
      }
      const lit = g.d >= T.creaseShade ? raw * cf : 0;
      if (raw > 0) { if (g.d < T.creaseShade) this.blockedCrease += raw * h; else { this.blockedCloud += raw * (1 - cf) * h; if (cf < 0.5) g.clouded = true; } }
      g.lit = lit;
      g.hp -= lit * h * T.burn;
      if (g.kind === 'hopper') {
        if (!g.hopping) {
          if (lit > 0 && !g.wasLit) { g.hopping = true; g.timer = 0; g.from = g.d; ev.push(['hopped', true]); }
          else { g.timer += h * (1 + T.hopHurry * lit); if (g.timer >= g.rest) { g.hopping = true; g.timer = 0; g.from = g.d; ev.push(['hopped', false]); } }
          g.tension = g.hopping ? 0 : Math.min(g.timer / g.rest, 1);
        } else {
          g.timer += h;
          const f = Math.min(g.timer / T.hopTime, 1);
          g.d = g.from + T.hopDist * smooth(f);
          g.tension = 0;
          if (f >= 1) { g.hopping = false; g.timer = 0; }
        }
      } else if (g.fling > 0) { g.d += T.splitFlingSpeed * h; g.fling -= h; g.tension = g.fling > 0 ? 1 : 0; }
      else g.d += g.speed * h;
      g.wasLit = lit > 0; g.age += h;
      if (g.hp <= 0) { this.pop(g, ev); if (g.kind === 'splitter') kids.push(g); continue; }
      if (g.d >= 1) { this.eat(g, ev); if (this.finished) return; continue; }
      this.glooms[w++] = g;
    }
    this.glooms.length = w;
    for (const p of kids) {
      ev.push(['split']);
      for (let i = 0; i < T.splitCount; i++) {
        const du = (i === 0 ? -1 : 1) * T.splitSpreadU;
        this.spawn('wisp', Math.min(Math.max(p.u + du, 0.03), 0.97), p.d + T.splitFling, p.speedScale, true);
      }
    }
    w = 0;
    for (let r = 0; r < this.ffs.length; r++) {
      const f = this.ffs[r];
      const dist = Math.max(0, Math.abs(f.d - b) - T.pad * T.ffRadius);
      const lit = on && f.d >= T.creaseShade ? intensityDist(dist) * (this.shades.length ? cloudFactor(f.u, this.shades) : 1) : 0;
      f.lit = lit;
      if (lit > 0) f.scorch += lit * h; else f.scorch = Math.max(0, f.scorch - T.ffDecay * h);
      f.d += f.speed * h; f.age += h;
      f.u = Math.min(Math.max(f.baseU + T.ffWaveAmp * Math.sin(2 * Math.PI * (f.age * T.ffWaveHz + f.phase)), 0.03), 0.97);
      if (f.scorch >= T.ffScorch) { this.scorched++; ev.push(['scorched']); this.breakChain(ev); continue; }
      if (f.d >= 1) { this.deliver(f, ev); continue; }
      this.ffs[w++] = f;
    }
    this.ffs.length = w;
    if (this.chain > 0 && now - this.lastPop > T.chainWindow) { ev.push(['chainEnded', this.chain]); this.chain = 0; this.sweep = 0; }
    if (!this.endless && now >= this.duration) this.sunrise(ev);
  }
  spawn(kind, u, d, s, flung, sd) {
    const sp = SPEC[kind];
    const d0 = d === null ? -sp.r : d;
    const sub = !flung && (sd || 0) > d0;
    const g = { id: this.nextId++, kind, u, d: d === null ? -sp.r : d, r: sp.r, hp: sp.hp, maxHP: sp.hp, lit: 0, age: 0, tension: flung ? 1 : 0,
      speed: sp.speed * s, speedScale: s, rest: T.hopRest / s, timer: 0, hopping: false, from: 0, fling: flung ? T.splitFlingTime : 0, wasLit: false, sub, sd: sub ? sd : 0 };
    this.glooms.push(g);
  }
  pop(g, ev) {
    const now = this.time;
    this.chain = (this.chain > 0 && now - this.lastPop <= T.chainWindow) ? this.chain + 1 : 1;
    this.sweep = (this.sweep > 0 && now - this.lastPop <= T.sweepWindow) ? this.sweep + 1 : 1;
    this.lastPop = now;
    this.longestChain = Math.max(this.longestChain, this.chain);
    const mult = Math.min(1 + T.chainStep * (this.chain - 1), T.maxMult);
    const pts = Math.round(SPEC[g.kind].pts * mult);
    this.score += pts; this.pops++;
    ev.push(['popped', g.kind, this.chain, pts]);
    if (this.sweep >= T.sweepMin) { const bonus = this.sweep === T.sweepMin ? T.sweepPer * T.sweepMin : T.sweepPer; this.score += bonus; ev.push(['swept', this.sweep, bonus]); }
  }
  breakChain(ev) { if (this.chain > 0) ev.push(['chainBroken', this.chain]); this.chain = 0; this.sweep = 0; }
  lane(u) { return Math.min(Math.max(Math.floor(u * 5), 0), 4); }
  eat(g, ev) {
    let lane = this.lane(g.u);
    if (!this.flowers[lane]) lane = this.nearest(lane, true);
    if (lane < 0) return;
    this.flowers[lane] = false; this.eaten++;
    const left = this.flowers.filter(x => x).length;
    ev.push(['eaten', lane, left, g.kind]);
    this.breakChain(ev);
    if (left === 0) { this.phase = 'lost'; ev.push(['nightWins']); }
  }
  nearest(lane, standing) {
    for (let k = 1; k < 5; k++) for (const c of [lane - k, lane + k]) if (c >= 0 && c < 5 && this.flowers[c] === standing) return c;
    return -1;
  }
  deliver(f, ev) {
    this.delivered++;
    let lane = this.lane(f.u);
    if (this.flowers.some(x => !x)) {
      if (this.flowers[lane]) lane = this.nearest(lane, false);
      this.flowers[lane] = true; ev.push(['delivered', lane, true, 0]);
    } else { this.score += T.ffBloom; ev.push(['delivered', lane, false, T.ffBloom]); }
  }
  sunrise(ev) {
    const left = this.flowers.filter(x => x).length;
    const bonus = T.flowerBonus * left; this.score += bonus;
    this.glooms = []; this.ffs = [];
    this.phase = left > 0 ? 'won' : 'lost';
    ev.push(['sunrise', left]);
  }
  snapshot() { return { phase: this.phase, glooms: this.glooms, ffs: this.ffs, shades: this.shades, band: this.band, time: this.time, flowers: this.flowers }; }
}

// ---------------- Pilot ----------------
const Pilot = require('./pilot.js')(T, SPEC, RNG, (u, sh) => cloudFactor(u, sh));

function run(spec, skill, seed, endless, cap, sessionSeed, parked) {
  const s = new Session(spec, sessionSeed === undefined ? seed : sessionSeed, endless);
  const p = new Pilot(skill, seed * 7 + 1);
  const dt = 1 / 60; let frames = 0; const maxF = (cap || 400) * 60;
  let fieldSum = 0, fieldN = 0;
  const lo = spec ? 0.25 * spec.duration : 60, hi = spec ? 0.9 * spec.duration : 1e9;
  while (!s.finished && frames < maxF) {
    const b = parked !== undefined ? parked : p.band_(s.snapshot(), dt);
    s.step(dt, { band: b, isShut: false });
    if (s.time >= lo && s.time <= hi) { fieldSum += s.glooms.length; fieldN++; }
    frames++;
  }
  return { won: s.phase === 'won', flowers: s.flowers.filter(x => x).length, score: s.score, eaten: s.eaten, scorched: s.scorched, delivered: s.delivered, time: s.time, chain: s.longestChain, pops: s.pops, field: fieldN ? fieldSum / fieldN : 0 };
}
module.exports = { run, level, daily, dailySeed, Session, Pilot, RNG, T, SPEC, cloudFactor };

if (require.main === module) {
  const seeds = Number(process.env.SEEDS || 3);
  const skills = (process.env.SKILLS || '0.3,0.6,0.9,1').split(',').map(Number);
  const only = process.env.LEVELS ? process.env.LEVELS.split(',').map(Number) : null;
  for (let n = 1; n <= 30; n++) {
    if (only && !only.includes(n)) continue;
    const spec = level(n);
    const parts = []; let field = 0;
    for (const sk of skills) {
      let won = 0, fl = 0, sc = 0, three = 0, ch = 0;
      for (let i = 0; i < seeds; i++) { const r = run(spec, sk, 1 + i * 7919); if (r.won) won++; if (r.flowers === 5 && r.score >= (spec.starScore || 0)) three++; fl += r.flowers; sc += r.score; ch = Math.max(ch, r.chain); if (sk === 0.6) field += r.field / seeds; }
      parts.push(`s${sk}: ${won}/${seeds} fl=${(fl / seeds).toFixed(1)} 3*=${three} ch=${ch} sc=${(sc / seeds).toFixed(0)}`);
    }
    const hp = spec.groups.reduce((a, g) => a + g.count * (g.kind === 'firefly' ? 0 : SPEC[g.kind].hp), 0);
    console.log(`L${String(n).padStart(2)} ${spec.duration}s hp=${hp.toFixed(0)} field=${field.toFixed(1)} | ` + parts.join(' | '));
  }
  if (process.env.EXTRA) {
    for (const sk of skills) {
      const ts = [], ss = []; let ch = 0; for (let i = 0; i < seeds; i++) { const r = run(null, sk, 1 + i * 7919, true, 1200); ts.push(r.time); ss.push(r.score); ch = Math.max(ch, r.chain); }
      ss.sort((a, b) => a - b); ts.sort((a, b) => a - b);
      console.log(`endless s${sk}: median time=${ts[ts.length >> 1].toFixed(0)} median score=${ss[ss.length >> 1].toFixed(0)} min=${ss[0]} max=${ss[ss.length - 1]} chain=${ch}`);
      let w = 0, f = 0; for (let d = 300; d < 300 + seeds; d++) { const r = run(daily(d), sk, 8, false, 200, dailySeed(d)); if (r.won) w++; f += r.flowers; }
      console.log(`daily s${sk}: won=${w}/${seeds} fl=${(f / seeds).toFixed(1)}`);
    }
  }
}
