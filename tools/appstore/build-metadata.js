// Builds docs/appstore/asc-metadata.json from the Glint docs, in the sister apps' schema (a port of
// C:\Users\59527\Trap\tools\appstore\build-metadata.js), and prints every count. Run from anywhere:
//   node C:\Users\59527\Sun\tools\appstore\build-metadata.js
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..', '..');
const rd = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const exists = f => fs.existsSync(path.join(root, f));
const problems = [], notes = [];
function blockAfter(text, marker) {
  const i = text.indexOf(marker); if (i < 0) throw new Error('marker ' + marker);
  const s = text.indexOf('```\n', i) + 4;
  const e = text.indexOf('\n```', s);
  return text.slice(s, e);
}
function need(text, what, file) { if (!text.includes(what)) problems.push(`${file} no longer says ${JSON.stringify(what)}`); }

const md = rd('docs/appstore/metadata.md');
const name = blockAfter(md, '## 1. App name');
const subtitle = blockAfter(md, '## 2. Subtitle');
const promo = blockAfter(md, '## 3. Promotional text');
const descGB = blockAfter(md, '### en-GB (English U.K.)');
const descUS = blockAfter(md, '### en-US (English U.S.)');
const keywords = blockAfter(md, '## 5. Keywords');
const whatsNew = blockAfter(md, '## 6. What\'s New');

// en-US must be en-GB with the US spellings only (metadata.md §4), so the two can't drift.
const usFromGB = descGB.replace(/synthesised/g, 'synthesized');
if (usFromGB !== descUS) problems.push('en-US description differs from en-GB beyond the listed spellings (metadata.md §4)');

const catRows = Object.fromEntries([...md.matchAll(/^\| (Primary|Game subcategory 1|Game subcategory 2|Secondary category) \| [^|]+\| `([A-Z_]+)` \|$/gm)].map(m => [m[1], m[2]]));
const categories = {
  _comment: 'metadata.md §7: Games, Arcade + Casual, secondary Entertainment. Apple dropped GAMES_ARCADE from its live list on 26 Oct 2026 (Brim run 40340641267; Swoop was filed as Casual + Action on 27 Oct). The categories step reads the live list first; a wanted subcategory that is not on it is replaced by the first live entry of fallbackSubcategories, or dropped. check/plan print what would be pushed.',
  primary: catRows['Primary'],
  primarySubcategories: [catRows['Game subcategory 1'], catRows['Game subcategory 2']].filter(Boolean),
  fallbackSubcategories: ['GAMES_ACTION'],
  secondary: catRows['Secondary category'] || null
};
if (categories.primary !== 'GAMES' || categories.primarySubcategories.length !== 2) problems.push('category table not parsed ' + JSON.stringify(catRows));

const site = 'https://pravegm.github.io/glint/';
for (const u of [site, site + 'support.html', site + 'privacy.html']) need(md, '`' + u + '`', 'metadata.md §9');
need(md, '**United Kingdom, £1.99**', 'metadata.md §9');
need(md, '**except China mainland and Vietnam**', 'metadata.md §9');
need(md, '**Manually release this version**', 'metadata.md §9');
const copyrightLine = (md.match(/^\| Copyright \| `([^`]+)` \|$/m) || [])[1];
if (!copyrightLine) problems.push('Copyright row not found');
const RELEASE = { type: 'MANUAL', earliestReleaseDate: null };
const LAUNCH = '2026-12-15T08:00:00Z';

const rn = rd('docs/appstore/review-notes.md');
const reviewNotes = blockAfter(rn, '<!-- REVIEW-NOTES:BEGIN -->');
if (!reviewNotes.startsWith('NO LOGIN')) problems.push('review notes must open with "NO LOGIN" (Swoop was auto-rejected under 2.1 for a missing demo account)');
const fn = rd('docs/appstore/featuring-nomination.md');
const nomDesc = blockAfter(fn, '### Description');
const nomNotes = blockAfter(fn, '### Helpful Details');
const nomName = (fn.match(/\| Nomination Name \| `([^`]+)`/) || [])[1];
need(fn, 'Specific day: 2026-12-15', 'featuring-nomination.md');

const ach = rd('docs/appstore/achievements.md');
const rows = ach.split('\n').filter(l => /^\| \d+ \| `glint\.ach\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
function split2(c) { const p = c.split(' / '); return [p[0], p[1] || p[0]]; }
const achievements = rows.map(r => {
  const id = r[1].replace(/`/g, '');
  const [tGB, tUS] = split2(r[2]), [bGB, bUS] = split2(r[3]), [aGB, aUS] = split2(r[4]);
  const hidden = /yes/i.test(r[6]);
  const loc = (n, b, a) => ({ name: n, beforeEarnedDescription: b, afterEarnedDescription: a });
  return { vendorIdentifier: id, referenceName: tGB, points: parseInt(r[5], 10), showBeforeEarned: !hidden, repeatable: false,
    localizations: { 'en-GB': loc(tGB, bGB, aGB), 'en-US': loc(tUS, bUS, aUS) }, image: `tools/appstore/badges/${id}.png` };
});
for (const s of ['`glint.endless`', '`glint.daily`', '`glint.stars`', '`Long Night`', '`Today\'s Dawn`', '`Total Stars`',
                 '` point` / ` points`', '` star` / ` stars`', '0 – 10,000,000', '0 – 90',
                 'Start **Tue 15 Dec 2026, 00:00 UTC** (launch day); duration **1 day**; repeats every **1 day**']) need(ach, s, 'achievements.md');
const lbLoc = (n, one, many) => ({ name: n, formatterSuffix: many, formatterSuffixSingular: one });
const leaderboards = [
  { vendorIdentifier: 'glint.endless', referenceName: 'Long Night', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 10000000, recurrence: null,
    localizations: { 'en-GB': lbLoc('Long Night', ' point', ' points'), 'en-US': lbLoc('Long Night', ' point', ' points') } },
  { vendorIdentifier: 'glint.daily', referenceName: 'Today\'s Dawn', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 10000000,
    recurrence: { startDate: '2026-12-15T00:00:00Z', duration: 'PT24H', rule: 'FREQ=DAILY;INTERVAL=1' },   // launch day (QA R5): never before the Game Center push
    localizations: { 'en-GB': lbLoc('Today\'s Dawn', ' point', ' points'), 'en-US': lbLoc('Today\'s Dawn', ' point', ' points') } },
  { vendorIdentifier: 'glint.stars', referenceName: 'Total stars', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 90, recurrence: null,
    localizations: { 'en-GB': lbLoc('Total Stars', ' star', ' stars'), 'en-US': lbLoc('Total Stars', ' star', ' stars') } }
];

// runbook cross-check
let rb = ''; try { rb = rd('docs/LAUNCH-RUNBOOK.md'); } catch (e) { problems.push('runbook missing'); }
const rbRows = rb.split('\n').filter(l => /^\| `glint\.ach\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
for (const r of rbRows) {
  const id = r[0].replace(/`/g, ''), a = achievements.find(x => x.vendorIdentifier === id);
  if (!a) { problems.push(`runbook lists ${id}, achievements.md does not`); continue; }
  const g = a.localizations['en-GB'];
  const cmp = [['title', r[1], g.name], ['before', r[2], g.beforeEarnedDescription], ['after', r[3], g.afterEarnedDescription], ['points', r[4], String(a.points)]];
  for (const [k, x, y] of cmp) if (x !== y) problems.push(`runbook ${id} ${k}: ${JSON.stringify(x)} vs ${JSON.stringify(y)}`);
}
if (rbRows.length !== achievements.length) problems.push(`runbook has ${rbRows.length} achievements, achievements.md ${achievements.length}`);

// Store frames (screenshots.md). Glint plays PORTRAIT on phones; the Duo set is the inner display in BOOK pose
// (2853x2007: the Duo simulator boots in book pose). The scenario files are the source of truth (store.yml).
const PFRAMES = ['01-hero', '02-sweep', '03-reach', '04-fireflies', '05-brute', '06-worlds', '07-rooftops', '08-harbour', '09-long-night', '10-todays-dawn'];
const DFRAMES = ['01-hero', '02-sweep', '03-reach', '04-fireflies', '05-brute', '06-worlds', '07-rooftops', '08-harbour', '09-long-night', '10-todays-dawn'];
const ssDoc = rd('docs/appstore/screenshots.md');
for (const n of PFRAMES) need(ssDoc, '`P' + n + '`', 'screenshots.md');
for (const n of DFRAMES) need(ssDoc, '`D' + n + '`', 'screenshots.md');
for (const [file, prefix, frames] of [['ci/store-scenarios.txt', 'P', PFRAMES], ['ci/duo-store-scenarios.txt', 'D', DFRAMES]]) {
  if (!exists(file)) { notes.push(`${file} missing (the store pipeline reads it): frame names checked against screenshots.md only`); continue; }
  const lines = rd(file).split('\n').filter(l => new RegExp('^' + prefix + '\\d\\d-').test(l));
  const names = lines.map(l => l.split('|')[0]);
  const want = frames.map(n => prefix + n);
  if (names.join() !== want.join()) problems.push(`${file} frames ${JSON.stringify(names)} != ${JSON.stringify(want)}`);
  for (const l of lines) {
    const f = l.split('|'), caption = f[3] || '';
    if (/\blid\b|lay (it|the phone) flat|\bfast\b|\bowls?\b/i.test(caption)) problems.push(`${file} ${f[0]}: caption breaks a copy rule: ${caption}`);
    if (prefix === 'P' && /(?:^|;)screen=cover/.test(f[1] || '')) problems.push(`${file} ${f[0]}: a Duo-only cover-display frame in the iPhone set`);
    const sub = (caption.split(' / ')[1] || '').trim();
    if (sub && !ssDoc.includes(sub)) problems.push(`screenshots.md does not quote ${f[0]}'s sub-line: ${sub}`);
  }
}
const screenshots = {
  _comment: 'store.yml (manual only) artifacts store-69 (6.9", 1320x2868 portrait), store-63 (6.3", 1206x2622 portrait: the "Dynamic Island, medium" slot, the APP_IPHONE_61 class) and store-duo (inner display 2853x2007, book pose). Frames P01-P10 / D01-D10 in ci/store-scenarios.txt / ci/duo-store-scenarios.txt order (frame 1 of every set is the book composite of D01, drawn at the angle that matches its light). Until a store run is given (store_run, or DEFAULT_STORE_RUN in asc.yml), validate reports them as gaps and push skips them.',
  APP_IPHONE_67: PFRAMES.map(n => `store-69/P${n}.png`),
  APP_IPHONE_61: PFRAMES.map(n => `store-63/P${n}.png`),
  duoInner: DFRAMES.map(n => `store-duo/D${n}.png`)
};

const meta = {
  _comment: 'Built from docs/appstore/metadata.md, review-notes.md, achievements.md and featuring-nomination.md by tools/appstore/build-metadata.js, in the sister apps\' schema; tools/appstore/asc.swift pushes it. Do not edit by hand: change the docs and regenerate. No personal data: the App Review contact is read at run time from Squish (--inherit-from com.pravegm.squish). The copyright is the public handle, not a personal name.',
  bundleId: 'com.pravegm.glint',
  primaryLocale: 'en-GB',
  copyrightHolder: copyrightLine || null,
  contentRights: 'DOES_NOT_USE_THIRD_PARTY_CONTENT',
  categories,
  localizations: {
    'en-GB': { name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: descGB, keywords, promotionalText: promo, supportUrl: site + 'support.html', marketingUrl: site },
    'en-US': { name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: descUS, keywords, promotionalText: promo, supportUrl: site + 'support.html', marketingUrl: site }
  },
  ageRating: {
    _comment: 'metadata.md §8: 4+; every content item None, every capability No, Contests None (leaderboards are not prize contests), not Made for Kids. Cartoon or Fantasy Violence is None on the condition in metadata.md §8 / §11 ask 1 (pops are sparks and petals, lit shadows steam and shrink, never shown hurt; an eaten flower is a drooping stalk); if the final art fails it, the answer becomes INFREQUENT_OR_MILD (9+) and the founder is told. Names from AgeRatingDeclarationUpdateRequest (as the sister apps).',
    parentalControls: false, ageAssurance: false, unrestrictedWebAccess: false, userGeneratedContent: false, messagingAndChat: false,
    advertising: false, socialMedia: false, socialMediaAgeRestricted: false,
    profanityOrCrudeHumor: 'NONE', horrorOrFearThemes: 'NONE', alcoholTobaccoOrDrugUseOrReferences: 'NONE', matureOrSuggestiveThemes: 'NONE',
    medicalOrTreatmentInformation: 'NONE', healthOrWellnessTopics: false, sexualContentOrNudity: 'NONE', sexualContentGraphicAndNudity: 'NONE',
    violenceCartoonOrFantasy: 'NONE', violenceRealistic: 'NONE', violenceRealisticProlongedGraphicOrSadistic: 'NONE', gunsOrOtherWeapons: 'NONE',
    gamblingSimulated: 'NONE', contests: 'NONE', gambling: false, lootBox: false, kidsAgeBand: null,
    ageRatingOverrideV2: 'NONE', koreaAgeRatingOverride: 'NONE'
  },
  review: { notes: reviewNotes, demoAccountRequired: false, contact: { firstName: null, lastName: null, phone: null, email: null } },
  release: { _comment: 'metadata.md §9 and §12: manual release; the founder presses Release This Version on Tue 15 Dec 2026 at about 08:00 UK (runbook §7). The tool never releases or submits.', ...RELEASE },
  price: { baseTerritory: 'GBR', customerPrice: '1.99' },
  availability: { _comment: 'metadata.md §9: every territory except China mainland and Vietnam (both need a local game licence; the sister apps exclude both). Mac and Vision Pro availability has no public API: the tool prints the clicks.', excludedTerritories: ['CHN', 'VNM'], availableInNewTerritories: true },
  achievements,
  leaderboards,
  screenshots,
  nomination: {
    _comment: 'docs/appstore/featuring-nomination.md. notes = Helpful Details. submit: false (R5): the tool saves it as a draft; the founder reads it and presses Submit in App Store Connect > Featuring > Nominations by Mon 23 Nov 2026 (3 weeks before launch). Set true to let the tool submit.',
    name: nomName, type: 'APP_LAUNCH', description: nomDesc, notes: nomNotes, publishStartDate: LAUNCH,
    deviceFamilies: ['IPHONE'], locales: ['en-GB', 'en-US'], supplementalMaterialsUris: [site],
    hasInAppEvents: false, launchInSelectMarketsFirst: false, preOrderEnabled: false, submit: false
  }
};

const c = s => [...s].length, b = s => Buffer.byteLength(s);
const placeholder = s => (s.includes('[') && s.includes(']')) || /todo|tbd|placeholder|example\.com|\{domain\}|<domain>/i.test(s);
const limits = [['name', name, 30], ['subtitle', subtitle, 30], ['promo', promo, 170], ['descGB', descGB, 4000], ['descUS', descUS, 4000], ['nomName', nomName, 60], ['nomDesc', nomDesc, 1000], ['nomNotes', nomNotes, 500]];
for (const [k, v, l] of limits) { if (!v) problems.push(`${k}: empty`); else { if (c(v) > l) problems.push(`${k}: ${c(v)} > ${l}`); if (placeholder(v)) problems.push(`${k}: placeholder-like`); } }
if (b(keywords) > 100) problems.push(`keywords ${b(keywords)} bytes`);
if (/\s/.test(keywords)) problems.push('keywords contain whitespace');
for (const w of ['glint', 'sun', 'mirror', 'catch', 'pop', 'shadow', 'shadows']) if (keywords.split(',').includes(w)) problems.push(`keyword "${w}" repeats the name or subtitle`);
if (b(reviewNotes) > 4000) problems.push(`notes ${b(reviewNotes)} bytes`);
if (/[^\x00-\x7F]/.test(reviewNotes)) problems.push('notes not ASCII: ' + JSON.stringify([...new Set(reviewNotes.match(/[^\x00-\x7F]/g))]));
if (placeholder(reviewNotes)) problems.push('notes placeholder-like');
const total = achievements.reduce((a, x) => a + x.points, 0);
if (achievements.length !== 10) problems.push(`achievements ${achievements.length}, expected 10`);
if (total !== 435) problems.push(`achievement points ${total}, the docs say 435`);
if (total > 1000) problems.push('points > 1000');
for (const a of achievements) { const t = a.localizations['en-GB'].name; if (c(t) > 30) problems.push('title > 30: ' + t); if (a.points > 100) problems.push('points > 100 ' + a.vendorIdentifier); }
// Copy rules (metadata.md "Words the copy uses"): nothing is hurt, say "phone" never "lid", no slogans, no competitors.
const banned = /\bkill|\bdie\b|\bdead\b|\bburn|\bzap|blast|smash|squish|\blid\b|fold to |open to |as fast as|\bowls?\b|porta nubi|lightfold|epinaelo|gleam/i;
const others = nomNotes.replace('Squish, Brim, Swoop, Hush and Snapjaw', '');
for (const [k, v] of [['name', name], ['subtitle', subtitle], ['promo', promo], ['descGB', descGB], ['descUS', descUS], ['keywords', keywords], ['notes', reviewNotes], ['nomDesc', nomDesc], ['nomNotes', others], ['whatsNew', whatsNew]]) if (banned.test(v)) problems.push(`${k} has a banned word: ${v.match(banned)[0]}`);
for (const a of achievements) for (const x of Object.values(a.localizations['en-GB'])) if (banned.test(x)) problems.push('banned word in ' + a.vendorIdentifier);
// Untrue or retired claims that must never appear: the research's draft subtitle and owls, a pose demand, the sister's words.
const stale = /tilt the sun|spare the owls|hold it like a book\.|respect silent switch|\bsnap/i;
for (const [k, v] of [['promo', promo], ['descGB', descGB], ['notes', reviewNotes], ['nomDesc', nomDesc], ['nomNotes', others], ['whatsNew', whatsNew]]) if (stale.test(v)) problems.push(`${k} repeats an untrue claim: ${v.match(stale)[0]}`);

fs.writeFileSync(path.join(root, 'docs/appstore/asc-metadata.json'), JSON.stringify(meta, null, 2) + '\n');
console.log({ name: c(name), subtitle: c(subtitle), promo: c(promo), descGB: c(descGB), descUS: c(descUS), kwBytes: b(keywords), notesBytes: b(reviewNotes),
  whatsNew: c(whatsNew), nomName: c(nomName), nomDesc: c(nomDesc), nomNotes: c(nomNotes), ach: achievements.length, pts: total, copyright: meta.copyrightHolder,
  categories: [categories.primary, ...categories.primarySubcategories, categories.secondary].join(' ') });
console.log(achievements.map(a => `${a.vendorIdentifier} ${a.points} t=${c(a.localizations['en-GB'].name)} | ${a.localizations['en-GB'].name} | ${a.localizations['en-GB'].beforeEarnedDescription} | ${a.localizations['en-GB'].afterEarnedDescription}`).join('\n'));

// screenshot headline counts (screenshots.md writes **headline** (n))
for (const m of ssDoc.matchAll(/\*\*([^*]*(?:\*[^*]+\*[^*]*)?)\*\* \((\d+)\)/g)) {
  const h = m[1].replace(/\*/g, ''); const n = c(h);
  console.log(`caption ${n} (doc says ${m[2]})${n !== +m[2] ? '  MISMATCH' : ''}${n > 30 ? '  TOO LONG' : ''} | ${h}`);
  if (n !== +m[2] || n > 30) problems.push(`screenshots.md caption "${h}": ${n} characters (doc says ${m[2]})`);
}
for (const n of notes) console.log('note: ' + n);
if (problems.length) { console.log('\nPROBLEMS:\n  ' + problems.join('\n  ')); process.exitCode = 1; } else console.log('\nOK');
