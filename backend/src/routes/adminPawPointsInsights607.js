'use strict';

/**
 * 607 (ADA, 02/10/2026) — onglet PawPoints de l'admin : chiffres et listes
 * qui n'avaient pas de route. LECTURE SEULE, requireAdmin.
 *
 *   GET /api/v1/admin/pawpoints-insights
 *
 * Aucune donnée en plus de ce que l'admin voit déjà : nom du profil, rôle,
 * identifiant, ville PUBLIABLE (règle publicCity607). Jamais d'e-mail, de
 * téléphone, d'adresse ni de position. Les comptes de test (+test) et
 * internes (staff, hopetsit@, dadaciao84@, sonde) sont exclus des chiffres
 * et signalés à part.
 *
 * Limites honnêtes (affichées par l'admin) :
 *  - « points distribués » = journal des gains d'activité (crédits réels)
 *    + peluches et bonus de peluches (barème, avant ×2 Premium / bonus de
 *    niveau). Les gains PawSpot ne sont pas journalisés : non comptés.
 *  - une peluche jamais attrapée est effacée 3 jours après son tirage.
 *
 * 611 (ADA, 04/10/2026) — Daniel : « sur l'admin, pas à jour ». Le tirage
 * d'Alhama affichait « 1 / 2 » attrapées mais la liste « vrais comptes » était
 * vide : la capture était celle d'un compte ÉQUIPE (isStaff, Premium offert),
 * comptée dans le tirage (l'original est bien pris) mais rangée avec les
 * comptes de test. Désormais chaque capture porte `kind` : 'real' | 'staff' |
 * 'test' ; le tirage détaille qui a attrapé (caughtReal / caughtStaff /
 * caughtTest + testCopies, les essais de test à part). Les chiffres « vrais
 * comptes » (plush7, points, actifs) restent hors équipe et hors test.
 */

const express = require('express');
const crypto = require('crypto');
const { requireAuth, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

const router = express.Router();
const requireAdmin = [requireAuth, requireRole('admin')];

const INTERNAL_EMAIL_RE = /(^hopetsit@|^dadaciao84@|@invalid\.example)/i;
const DAY = 86400000;

const MODELS = {
  owner: () => require('../models/Owner'),
  sitter: () => require('../models/Sitter'),
  walker: () => require('../models/Walker'),
};
const normRole = (r) => {
  const s = String(r || '').toLowerCase();
  return s === 'sitter' || s === 'walker' ? s : 'owner';
};
const dayKey = (d) => new Date(d).toISOString().slice(0, 10);

function plainEmail(stored) {
  let e = stored;
  try { e = require('../utils/encryption').decrypt(stored); } catch (_) { /* en clair */ }
  return String(e || '').toLowerCase().trim();
}

/** Classe un profil : 'real' | 'test' | 'internal'. */
function kindOf(doc) {
  if (!doc) return 'real';
  const email = plainEmail(doc.email);
  if (/\+test/i.test(email)) return 'test';
  if (doc.isStaff === true || INTERNAL_EMAIL_RE.test(email)) return 'internal';
  return 'real';
}

/** Charge nom / rôle / type des profils cités ({role:[ids]}) → Map "role:id". */
async function loadPeople(idsByRole) {
  const out = new Map();
  await Promise.all(Object.entries(idsByRole).map(async ([role, ids]) => {
    const list = [...new Set(ids.filter(Boolean).map(String))]
      .filter((id) => /^[a-f0-9]{24}$/i.test(id));
    if (!list.length) return;
    const docs = await MODELS[role]().find({ _id: { $in: list } })
      .select('name firstName email isStaff city location.city homeLocation.city coverageCity').lean();
    const { cityOfDoc } = require('../utils/publicProvider607');
    docs.forEach((d) => {
      const email = plainEmail(d.email);
      out.set(`${role}:${String(d._id)}`, {
        name: d.name || d.firstName || '',
        kind: kindOf(d),
        city: cityOfDoc(d),
        person: email ? crypto.createHash('sha256').update(email).digest('hex').slice(0, 16) : `id:${d._id}`,
      });
    });
  }));
  return out;
}

const short = (id) => String(id || '').slice(-6);

/** Type d'une capture : 'test' (copie ou compte +test), 'staff' (équipe / interne), 'real'. */
function catchKind(p, w) {
  if (p && p.testCopy) return 'test';
  if (w && w.kind === 'test') return 'test';
  if (w && w.kind === 'internal') return 'staff';
  return 'real';
}

router.get('/', requireAdmin, async (req, res) => {
  const t0 = Date.now();
  try {
    const now = Date.now();
    const since7 = new Date(now - 7 * DAY);
    const since30 = new Date(now - 30 * DAY);

    const PawPointsEvent = require('../models/PawPointsEvent');
    const PawRewardRedemption = require('../models/PawRewardRedemption');
    let PawPlush = null;
    let PawPlushBonus = null;
    try {
      PawPlush = require('../models/PawPlush');
      PawPlushBonus = PawPlush.PawPlushBonus;
    } catch (_) { PawPlush = null; }

    const [events30, pioneerEvents, plush30, bonus30, redemptions30] = await Promise.all([
      PawPointsEvent.find({ at: { $gte: since30 } }).select('userId role key credited at').lean(),
      PawPointsEvent.find({ key: 'pioneer' }).sort({ at: -1 }).limit(500).select('userId role credited at').lean(),
      PawPlush ? PawPlush.find({ caughtByPerson: { $type: 'string' }, 'caughtBy.at': { $gte: since30 } })
        .sort({ 'caughtBy.at': -1 }).select('type golden cityLabel day caughtByPerson caughtBy testCopy').lean() : [],
      PawPlushBonus ? PawPlushBonus.find({ at: { $gte: since30 } }).select('personKey kind points at').lean() : [],
      PawRewardRedemption.find({ createdAt: { $gte: since30 } }).select('status createdAt userId userModel role').lean(),
    ]);

    // Profils cités (événements, peluches, pionniers).
    const ids = { owner: [], sitter: [], walker: [] };
    events30.concat(pioneerEvents).forEach((e) => ids[normRole(e.role)].push(e.userId));
    plush30.forEach((p) => p.caughtBy && ids[normRole(p.caughtBy.role)].push(p.caughtBy.userId));
    const redRole = (r) => normRole(r.role || String(r.userModel || '').toLowerCase());
    redemptions30.forEach((r) => ids[redRole(r)].push(String(r.userId)));
    const people = await loadPeople(ids);
    const who = (role, id) => people.get(`${normRole(role)}:${String(id)}`) || { name: '', kind: 'real', city: '', person: `id:${id}` };

    // Personnes « de test » côté peluches (clé de personne des copies de test).
    const testPlushPersons = new Set();
    plush30.forEach((p) => {
      const w = p.caughtBy ? who(p.caughtBy.role, p.caughtBy.userId) : null;
      if (p.testCopy || (w && w.kind !== 'real')) testPlushPersons.add(p.caughtByPerson);
    });

    // ── Chiffres du haut (vrais comptes seulement) ──
    const k = { points7: 0, points30: 0, journal30: 0, plushPoints30: 0, bonusPoints30: 0 };
    const active = new Set();
    events30.forEach((e) => {
      const w = who(e.role, e.userId);
      if (w.kind !== 'real') return;
      const pts = Number(e.credited || 0);
      k.points30 += pts; k.journal30 += pts;
      if (new Date(e.at) >= since7) k.points7 += pts;
      active.add(w.person);
    });
    let plush7 = 0; let plush7Test = 0; let plush7Staff = 0; let plush30Real = 0;
    plush30.forEach((p) => {
      const w = p.caughtBy ? who(p.caughtBy.role, p.caughtBy.userId) : null;
      const kind = catchKind(p, w);
      const recent = p.caughtBy && new Date(p.caughtBy.at) >= since7;
      if (kind !== 'real') {
        if (recent) { if (kind === 'staff') plush7Staff += 1; else plush7Test += 1; }
        return;
      }
      plush30Real += 1;
      if (recent) plush7 += 1;
      const pts = p.golden ? 200 : 20;
      k.points30 += pts; k.plushPoints30 += pts;
      if (recent) k.points7 += pts;
      if (w) active.add(w.person);
    });
    bonus30.forEach((b) => {
      if (testPlushPersons.has(b.personKey)) return;
      const pts = Number(b.points || 0);
      k.points30 += pts; k.bonusPoints30 += pts;
      if (new Date(b.at) >= since7) k.points7 += pts;
    });
    const redStatus = { pending: 0, fulfilled: 0, cancelled: 0 };
    let redReal = 0; let redTest = 0;
    redemptions30.forEach((r) => {
      if (who(redRole(r), r.userId).kind !== 'real') { redTest += 1; return; }
      redReal += 1;
      redStatus[r.status] = (redStatus[r.status] || 0) + 1;
    });

    // ── Peluches : tirages du jour par ville (jour LOCAL de la ville : on
    // garde le jour le plus récent de chaque ville parmi hier/aujourd'hui/demain UTC) ──
    let draws = [];
    let goldenWeek = [];
    if (PawPlush) {
      const days = [dayKey(now - DAY), dayKey(now), dayKey(now + DAY)];
      const agg = await PawPlush.aggregate([
        { $match: { day: { $in: days }, copyOf: null } },
        {
          $group: {
            _id: { city: '$cityKey', day: '$day' },
            label: { $first: '$cityLabel' },
            total: { $sum: 1 },
            golden: { $sum: { $cond: ['$golden', 1, 0] } },
            caught: { $sum: { $cond: [{ $eq: [{ $type: '$caughtByPerson' }, 'string'] }, 1, 0] } },
            catchers: {
              $push: {
                $cond: [{ $eq: [{ $type: '$caughtByPerson' }, 'string'] },
                  { u: '$caughtBy.userId', r: '$caughtBy.role' }, '$$REMOVE'],
              },
            },
          },
        },
      ]);
      const byCity = new Map();
      agg.forEach((a) => {
        const cur = byCity.get(a._id.city);
        if (!cur || a._id.day > cur.day) {
          byCity.set(a._id.city, { key: a._id.city, city: a.label || a._id.city, day: a._id.day, total: a.total, golden: a.golden, caught: a.caught, catchers: a.catchers || [] });
        }
      });
      // Qui a attrapé les peluches du tirage (vrai compte / équipe / test).
      const cIds = { owner: [], sitter: [], walker: [] };
      byCity.forEach((d) => d.catchers.forEach((c) => c.u && cIds[normRole(c.r)].push(c.u)));
      const cPeople = await loadPeople(cIds);
      // Essais des comptes de test sur ce tirage : copies à part (cityKey « test:<ville>:<personne> »).
      const copies = await PawPlush.find({ day: { $in: days }, testCopy: true })
        .select('cityKey day').lean();
      const copyCount = new Map();
      copies.forEach((c) => {
        const ck = String(c.cityKey || '');
        if (!ck.startsWith('test:')) return;
        const orig = ck.slice(5, ck.lastIndexOf(':') > 4 ? ck.lastIndexOf(':') : ck.length);
        const kk = `${orig}|${c.day}`;
        copyCount.set(kk, (copyCount.get(kk) || 0) + 1);
      });
      draws = [...byCity.values()].map((d) => {
        const out = { city: d.city, day: d.day, total: d.total, golden: d.golden, caught: d.caught, caughtReal: 0, caughtStaff: 0, caughtTest: 0 };
        d.catchers.forEach((c) => {
          const w = cPeople.get(`${normRole(c.r)}:${String(c.u)}`) || null;
          const kind = catchKind(null, w);
          if (kind === 'staff') out.caughtStaff += 1; else if (kind === 'test') out.caughtTest += 1; else out.caughtReal += 1;
        });
        out.testCopies = copyCount.get(`${d.key}|${d.day}`) || 0;
        return out;
      }).sort((a, b) => b.total - a.total || a.city.localeCompare(b.city));

      const gold = await PawPlush.find({ golden: true, copyOf: null, createdAt: { $gte: since7 } })
        .sort({ day: -1 }).limit(100).select('type cityLabel day caughtByPerson caughtBy').lean();
      const gIds = { owner: [], sitter: [], walker: [] };
      gold.forEach((g) => g.caughtBy && g.caughtBy.userId && gIds[normRole(g.caughtBy.role)].push(g.caughtBy.userId));
      const gPeople = await loadPeople(gIds);
      goldenWeek = gold.map((g) => {
        const caught = typeof g.caughtByPerson === 'string';
        const w = caught ? gPeople.get(`${normRole(g.caughtBy.role)}:${String(g.caughtBy.userId)}`) : null;
        return {
          city: g.cityLabel || '', day: g.day, type: g.type, caught,
          at: caught ? g.caughtBy.at : null,
          by: caught ? { id: short(g.caughtBy.userId), name: (w && w.name) || '', role: normRole(g.caughtBy.role), kind: catchKind(null, w), test: catchKind(null, w) === 'test' } : null,
        };
      });
    }

    // Toutes les captures des 30 jours (200 au plus), chacune avec son type :
    // l'admin les montre toutes avec une pastille et filtre à l'affichage.
    const recentCatches = plush30.slice(0, 200).map((p) => {
      const w = p.caughtBy ? who(p.caughtBy.role, p.caughtBy.userId) : null;
      const kind = catchKind(p, w);
      return {
        at: p.caughtBy ? p.caughtBy.at : null, day: p.day, type: p.type, golden: !!p.golden,
        city: p.cityLabel || '', role: p.caughtBy ? normRole(p.caughtBy.role) : '',
        id: p.caughtBy ? short(p.caughtBy.userId) : '', name: (w && w.name) || '',
        kind,
        test: kind === 'test',
      };
    });

    // ── Pionniers : bonus +200 versés (journal) ──
    const pioneers = pioneerEvents.map((e) => {
      const w = who(e.role, e.userId);
      return { at: e.at, role: normRole(e.role), id: short(e.userId), name: w.name, city: w.city, credited: Number(e.credited || 0), test: w.kind !== 'real' };
    });

    // ── Liens personnels /s/<slug> ──
    const { isTaintedSlug } = require('../utils/publicSlug607');
    const { cityOfDoc } = require('../utils/publicProvider607');
    const links = { sitter: 0, walker: 0, total: 0, providers: 0, noCity: [], noCityCount: 0 };
    for (const role of ['sitter', 'walker']) {
      const docs = await MODELS[role]().find({})
        .select('name firstName email isStaff hiddenFromPublic bannedAt status publicSlug city location.city homeLocation.city coverageCity createdAt')
        .limit(20000).lean();
      docs.forEach((d) => {
        if (kindOf(d) !== 'real' || d.hiddenFromPublic === true || d.bannedAt
          || d.status === 'banned' || d.status === 'suspended') return;
        links.providers += 1;
        if (d.publicSlug && !isTaintedSlug(d.publicSlug, d)) { links[role] += 1; links.total += 1; }
        if (!cityOfDoc(d)) {
          const raw = (d.homeLocation && d.homeLocation.city) || d.city || (d.location && d.location.city) || d.coverageCity || '';
          links.noCityCount += 1;
          links.noCity.push({
            id: short(d._id), role, name: d.name || d.firstName || '',
            reason: String(raw).trim() ? 'unsafe' : 'empty', since: d.createdAt || null,
          });
        }
      });
    }
    links.noCity.sort((a, b) => new Date(b.since || 0) - new Date(a.since || 0));
    links.noCity = links.noCity.slice(0, 200);

    return res.json({
      generatedAt: new Date(now).toISOString(),
      kpis: {
        points7: k.points7,
        points30: k.points30,
        parts30: { journal: k.journal30, plush: k.plushPoints30, plushBonus: k.bonusPoints30 },
        activeUsers30: active.size,
        redemptions30: redReal,
        redemptions30Test: redTest,
        redemptionsByStatus30: redStatus,
        plush7, plush7Test, plush7Staff, plush30: plush30Real,
      },
      plush: { available: !!PawPlush, draws, goldenWeek, recent: recentCatches },
      pioneers: { count: pioneers.filter((p) => !p.test).length, testCount: pioneers.filter((p) => p.test).length, list: pioneers },
      links,
      ms: Date.now() - t0,
    });
  } catch (e) {
    logger.error({ err: e }, '[admin/pawpoints-insights]');
    return res.status(500).json({ error: 'Erreur.' });
  }
});

module.exports = router;
