// ZOE (15/10/2026) — CGU 2.4 : clause « Responsabilité individuelle et conformité
// aux législations applicables » (texte de Daniel, 14/10). Trois garde-fous :
//   1. les sources des 3 surfaces portent la clause (règlement (UE) 2022/2065) —
//      site 9 langues, app 6 langues en version 2.4 ;
//   2. le texte français embarqué dans l'app est MOT POUR MOT celui de Daniel ;
//   3. le serveur sert bien un document 2.4 avec la clause par GET /terms/:lang
//      (base en mémoire, même chemin que la production : TermsDocument → termsRoutes).
process.env.NODE_ENV = 'test';

const fs = require('fs');
const path = require('path');
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const ROOT = path.resolve(__dirname, '../..');
const DART = path.join(ROOT, 'frontend/lib/data/static/terms_of_service.dart');
const SITE = path.join(ROOT, 'website/src/lib/legalContent.ts');
const CLAUSE = '2022/2065';
const APP_LANGS = { En: 'en', Fr: 'fr', Es: 'es', De: 'de', It: 'it', Pt: 'pt' };
const SITE_LANGS = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const DANIEL_FR = [
  "Chaque utilisateur de HoPetSit, qu'il soit particulier ou professionnel, est personnellement responsable de vérifier que les activités et prestations qu'il propose ou réalise sont légalement autorisées dans son pays de résidence et dans le pays où elles sont exercées.",
  "Il s'engage à respecter l'ensemble des lois et réglementations locales, nationales et internationales applicables, notamment en matière de qualifications, diplômes, certifications, autorisations administratives, déclarations professionnelles, obligations fiscales et sociales, assurances et protection du bien-être animal.",
  "L'inscription sur HoPetSit et la génération de documents de facturation ne constituent en aucun cas une autorisation légale d'exercer.",
  "HoPetSit intervient exclusivement en qualité de plateforme numérique de mise en relation et ne constitue pas l'employeur des prestataires indépendants.",
  "Conformément à l'article 8 du règlement européen (UE) 2022/2065 (Digital Services Act), les fournisseurs de services intermédiaires concernés ne sont pas soumis à une obligation générale de surveillance des informations qu'ils transmettent ou stockent.",
  "Chaque utilisateur demeure responsable des conséquences de ses propres manquements à la réglementation applicable, sans préjudice des obligations légales propres à HoPetSit, notamment en matière de traitement des signalements, de sécurité et de coopération avec les autorités compétentes.",
  "Cette clause s'applique sous réserve des dispositions impératives en vigueur dans chaque juridiction.",
];

function dartBlocks() {
  const src = fs.readFileSync(DART, 'utf8');
  const version = /const String termsVersion = '([^']+)'/.exec(src)[1];
  const blocks = {};
  for (const [suf, lang] of Object.entries(APP_LANGS)) {
    const m = new RegExp(`const String _terms${suf} = r"""\\n([\\s\\S]*?)""";`).exec(src);
    blocks[lang] = m[1].trim();
  }
  return { version, blocks };
}

describe('CGU 2.4 — clause responsabilité individuelle (sources des 3 surfaces)', () => {
  const { version, blocks } = dartBlocks();

  test('app : termsVersion 2.4, en-tête 2.4 et clause dans les 6 langues', () => {
    expect(version).toBe('2.4');
    for (const [lang, t] of Object.entries(blocks)) {
      expect(t).toMatch(/(Version|Versión|Versione|Versão) 2\.4 /);
      expect(t).not.toMatch(/(Version|Versión|Versione|Versão) 2\.3 /);
      expect(t.split(CLAUSE).length - 1).toBe(1);
      expect(t.indexOf(CLAUSE)).toBeLessThan(t.indexOf('\n## 9. '));
      expect(lang).toBeTruthy();
    }
  });

  test('app : le français est mot pour mot le texte de Daniel, dans l\'ordre', () => {
    const fr = blocks.fr;
    expect(fr).toContain('## 8 ter. Responsabilité individuelle et conformité aux législations applicables');
    let last = -1;
    for (const p of DANIEL_FR) {
      const i = fr.indexOf(p);
      expect(i).toBeGreaterThan(last);
      last = i;
    }
  });

  test('site : clause en article 8 dans les 9 langues, datée du 15 octobre 2026', () => {
    const src = fs.readFileSync(SITE, 'utf8');
    const terms = src.slice(src.indexOf('export const TERMS'), src.indexOf('export const PRIVACY'));
    for (const lang of SITE_LANGS) {
      const start = terms.indexOf(`\n  ${lang}: {\n`);
      expect(start).toBeGreaterThan(-1);
      const rest = terms.slice(start + 5);
      const next = /\n  [a-z]{2}: \{\n/.exec(rest);
      const block = next ? rest.slice(0, next.index) : rest;
      expect(block.split(CLAUSE).length - 1).toBe(1);
      expect(block).toMatch(/html: `8\. /);
      expect(block).toMatch(/html: `14\. /);
      expect(block).toMatch(/lastUpdated: "(October 15, 2026|15 octobre 2026|15 de octubre de 2026|15\. Oktober 2026|15 ottobre 2026|15 de outubro de 2026|2026년 10월 15일|2026年10月15日)"/);
    }
    // Le français du site = celui de Daniel, paragraphe par paragraphe.
    for (const p of DANIEL_FR) expect(terms).toContain('html: `' + p + '`');
  });
});

describe('CGU 2.4 — GET /terms/:lang sert le document 2.4 (base en mémoire)', () => {
  let mongo; let app; let TermsDocument;
  beforeAll(async () => {
    mongo = await MongoMemoryServer.create();
    await mongoose.connect(mongo.getUri());
    TermsDocument = require('../src/models/TermsDocument');
    const { blocks } = dartBlocks();
    for (const [lang, content] of Object.entries(blocks)) {
      await TermsDocument.create({ language: lang, content, version: '2.4', updatedBy: 'test' });
    }
    app = express();
    app.use(express.json());
    app.use('/terms', require('../src/routes/termsRoutes'));
  }, 60000);
  afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 30000);

  test.each(Object.values(APP_LANGS))('%s : 200, version 2.4, clause présente', async (lang) => {
    const res = await request(app).get(`/terms/${lang}`);
    expect(res.status).toBe(200);
    expect(res.body.version).toBe('2.4');
    expect(res.body.content).toContain(CLAUSE);
    expect(res.body.content).toMatch(/(Version|Versión|Versione|Versão) 2\.4 /);
  });

  test('fr-FR est normalisé en fr ; une langue inconnue répond 400', async () => {
    expect((await request(app).get('/terms/fr-FR')).body.language).toBe('fr');
    expect((await request(app).get('/terms/xx')).status).toBe(400);
  });
});
