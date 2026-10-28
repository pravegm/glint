// PilotBrain mirror (R2: crease shade aware, human-hinge model).
module.exports = function (T, SPEC, RNG, cloudFactor) {
  const E = (k, d) => (process.env[k] !== undefined ? Number(process.env[k]) : d);
  return class Pilot {
    constructor(skill, seed) {
      const s = Math.min(Math.max(skill, 0), 1); this.skill = s; this.rng = new RNG(seed);
      const w = 1 - s;
      this.reaction = 0.35 - 0.27 * s; this.cap = 0.9 + 0.7 * s;
      this.aimNoise = 0.005 + E('NOISE', 0.08) * w; this.slip = E('SLIP', 0.4) * w;
      this.hesitate = 0.5 * w; this.switchMargin = 0.8 - 0.5 * s; this.ffMargin = 0.097 + 0.035 * s;
      // R2 human hinge: jitter, lag, overshoot, all scaled by (1 - skill)
      this.jitterAmp = E('JIT', 0.05) * w; this.hingeLag = E('LAG0', 0.1) + E('LAG1', 0.25) * w; this.overshootChance = E('OVER', 0.6) * w;
      this.band = T.bandMin; this.hand = T.bandMin; this.goal = 0.2; this.target = -1; this.decideIn = 0; this.freeze = 0; this.err = 0; this.errIn = 0;
      this.jit = 0; this.jitTarget = 0; this.jitIn = 0; this.over = 0; this.out = T.bandMin;
    }
    speedOf(g) { if (g.tension >= 1 && g.kind === 'wisp') return T.splitFlingSpeed; return SPEC[g.kind].speed; }
    urgency(g, glooms, shades) {
      const sp = Math.max(this.speedOf(g), 0.02);
      const arrive = (1 - g.d - (g.kind === 'splitter' ? 0.25 : 0)) / sp;
      const trip = Math.abs(this.band - Math.max(g.d, T.creaseShade)) / this.cap;
      const raw = arrive - g.hp - trip;
      let slack = raw;
      let near = 0; for (const o of glooms) if (o.id !== g.id && Math.abs(o.d - g.d) < 0.06) near++;
      slack -= 0.25 * Math.min(near, 4);
      if (shades && shades.length) { const cf = cloudFactor(g.u, shades); if (cf < 0.6) slack += 2.5 * (1 - cf); }
      if (raw < -0.3) slack += 8;
      return -slack;
    }
    band_(snap, dt) {
      if (dt <= 0) return this.out;
      const s = this.skill;
      this.errIn -= dt;
      if (this.errIn <= 0) { this.errIn = 0.3 + 0.5 * this.rng.unit(); this.err = this.aimNoise * (2 * this.rng.unit() - 1); }
      this.jitIn -= dt;
      if (this.jitIn <= 0) { this.jitIn = 0.12; this.jitTarget = this.jitterAmp * (2 * this.rng.unit() - 1); }
      this.jit += (this.jitTarget - this.jit) * Math.min(1, dt / 0.06);
      this.over *= Math.exp(-dt / 0.2);
      if (this.freeze > 0) { this.freeze -= dt; return this.output(dt); }
      if (this.rng.unit() < this.hesitate * dt) { this.freeze = 0.2 + 0.6 * (1 - s) * this.rng.unit(); return this.output(dt); }
      const gl = snap.glooms;
      let tg = null;
      for (const g of gl) if (g.id === this.target) { tg = g; break; }
      this.decideIn -= dt;
      if (tg === null && this.decideIn > this.reaction) this.decideIn = this.reaction;
      if (this.decideIn <= 0) {
        this.decideIn = this.reaction;
        let best = null, bu = -1e9;
        for (const g of gl) { const u = this.urgency(g, gl, snap.shades); if (u > bu) { bu = u; best = g; } }
        if (gl.length > 1 && this.rng.unit() < this.slip) best = gl[this.rng.int(0, gl.length - 1)];
        if (best !== null && tg !== null && tg.lit > 0.3 && best.id !== tg.id) {
          if (this.urgency(best, gl, snap.shades) < this.urgency(tg, gl, snap.shades) + this.switchMargin) best = tg;
        }
        const newId = best !== null ? best.id : -1;
        if (best !== null && newId !== this.target) {
          const jump = Math.max(best.d, T.creaseShade) - this.hand;
          const roll = this.rng.unit();
          if (Math.abs(jump) > 0.15 && roll < this.overshootChance) {
            this.over = (jump > 0 ? 1 : -1) * (0.04 + 0.08 * this.rng.unit()) * (1 - s);
          }
        }
        this.target = newId; tg = best;
      }
      let aim = T.creaseShade + 0.08, careless = false;
      if (tg !== null) {
        if (tg.kind === 'hopper') aim = tg.tension < 0.02 ? tg.d + 0.06 : tg.d + 0.02 + 0.03 * s;
        else aim = tg.d + this.speedOf(tg) * (this.reaction + 0.05) * s;
        aim = Math.max(aim, T.creaseShade + 0.05);
        careless = tg.d > 0.6;
      }
      aim += this.err + this.over;
      if (!careless && snap.ffs.length > 0) {
        const m = this.ffMargin, ff = snap.ffs;
        let bestAim = aim, bestCost = 1e9;
        for (let c = -1; c < 2 * ff.length; c++) {
          const cand = c < 0 ? aim : ff[c >> 1].d + ((c & 1) === 0 ? -m : m) * 1.0001;
          let ok = true; for (const q of ff) if (q.d > T.creaseShade - 0.1 && Math.abs(cand - q.d) < m) { ok = false; break; }
          if (!ok) continue;
          const cost = Math.abs(cand - aim);
          if (cost < bestCost) { bestCost = cost; bestAim = cand; }
        }
        aim = bestAim;
      }
      aim = Math.min(Math.max(aim, T.bandMin), 1);
      this.goal += (aim - this.goal) * Math.min(1, dt / (0.5 * this.reaction));
      let v = (this.goal - this.hand) / 0.06;
      v = Math.min(Math.max(v, -this.cap), this.cap);
      this.hand = Math.min(Math.max(this.hand + v * dt, T.bandMin), 1);
      return this.output(dt);
    }
    output(dt) {
      // The hinge: the band follows the hand through a lag, plus a jitter.
      this.band += (this.hand - this.band) * Math.min(1, dt / this.hingeLag);
      this.out = Math.min(Math.max(this.band + this.jit, T.bandMin), 1);
      return this.out;
    }
  };
};
