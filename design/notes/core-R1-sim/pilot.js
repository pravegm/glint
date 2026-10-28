module.exports = function (T, SPEC, RNG) {
  return class Pilot {
    constructor(skill, seed) {
      const s = Math.min(Math.max(skill, 0), 1); this.skill = s; this.rng = new RNG(seed);
      this.reaction = 0.35 - 0.27 * s; this.cap = 0.9 + 0.7 * s;
      this.aimNoise = 0.005 + (Number(process.env.NOISE || 0.15)) * (1 - s); this.slip = (Number(process.env.SLIP || 0.6)) * (1 - s);
      this.hesitate = 0.5 * (1 - s); this.switchMargin = Number(process.env.SWA || 0.8) - Number(process.env.SWB || 0.5) * s; this.ffMargin = 0.097 + 0.035 * s;
      this.band = T.bandMin; this.goal = 0.06; this.target = -1; this.decideIn = 0; this.freeze = 0; this.err = 0; this.errIn = 0;
    }
    speedOf(g) { if (g.tension >= 1 && g.kind === 'wisp') return T.splitFlingSpeed; return SPEC[g.kind].speed; }
    urgency(g, glooms) {
      // seconds of slack: time until it reaches the flowers, minus the light it still needs and the trip to it
      const sp = Math.max(this.speedOf(g), 0.02);
      const arrive = (1 - g.d - (g.kind === 'splitter' ? 0.25 : 0)) / sp;
      const trip = Math.abs(this.band - g.d) / this.cap;
      const raw = arrive - g.hp - trip;
      let slack = raw;
      let near = 0; for (const o of glooms) if (o.id !== g.id && Math.abs(o.d - g.d) < 0.06) near++;
      slack -= 0.25 * Math.min(near, 4);
      if (raw < -0.3) slack += 8;        // hopeless: let it go
      return -slack;
    }
    band_(snap, dt) {
      if (dt <= 0) return this.band;
      const s = this.skill;
      this.errIn -= dt;
      if (this.errIn <= 0) { this.errIn = 0.3 + 0.5 * this.rng.unit(); this.err = this.aimNoise * (2 * this.rng.unit() - 1); }
      if (this.freeze > 0) { this.freeze -= dt; return this.band; }
      if (this.rng.unit() < this.hesitate * dt) { this.freeze = 0.2 + 0.6 * (1 - s) * this.rng.unit(); return this.band; }
      const gl = snap.glooms;
      let tg = null;
      for (const g of gl) if (g.id === this.target) { tg = g; break; }
      this.decideIn -= dt;
      if (tg === null && this.decideIn > this.reaction) this.decideIn = this.reaction;
      if (this.decideIn <= 0) {
        this.decideIn = this.reaction;
        let best = null, bu = -1e9;
        for (const g of gl) { const u = this.urgency(g, gl); if (u > bu) { bu = u; best = g; } }
        if (gl.length > 1 && this.rng.unit() < this.slip) best = gl[this.rng.int(0, gl.length - 1)];
        if (best !== null && tg !== null && tg.lit > 0.3 && best.id !== tg.id) {
          if (this.urgency(best, gl) < this.urgency(tg, gl) + this.switchMargin) best = tg;
        }
        this.target = best !== null ? best.id : -1; tg = best;
      }
      let aim = 0.06, careless = false;
      if (tg !== null) {
        if (tg.kind === 'hopper') aim = tg.tension < 0.02 ? tg.d + 0.06 : tg.d + 0.02 + 0.03 * s;
        else aim = tg.d + this.speedOf(tg) * (this.reaction + 0.05) * s;
        careless = tg.d > Number(process.env.CARE || 0.6);
      }
      aim += this.err;
      if (!careless && snap.ffs.length > 0) {
        const m = this.ffMargin, ff = snap.ffs;
        let bestAim = aim, bestCost = 1e9;
        for (let c = -1; c < 2 * ff.length; c++) {
          const cand = c < 0 ? aim : ff[c >> 1].d + ((c & 1) === 0 ? -m : m) * 1.0001;
          let ok = true; for (const q of ff) if (Math.abs(cand - q.d) < m) { ok = false; break; }
          if (!ok) continue;
          const cost = Math.abs(cand - aim);
          if (cost < bestCost) { bestCost = cost; bestAim = cand; }
        }
        aim = bestAim;
      }
      aim = Math.min(Math.max(aim, T.bandMin), 1);
      this.goal += (aim - this.goal) * Math.min(1, dt / (0.5 * this.reaction));
      let v = (this.goal - this.band) / 0.06;
      v = Math.min(Math.max(v, -this.cap), this.cap);
      this.band = Math.min(Math.max(this.band + v * dt, T.bandMin), 1);
      return this.band;
    }
  };
};
