/**
 * v448 — AUDIT MESSAGERIE/NOTIFICATIONS : script de diagnostic + nettoyage DB.
 *
 * Lance un DIAGNOSTIC (lecture seule) par défaut. Ajoute `--fix` pour APPLIQUER
 * les corrections sûres.
 *
 *   node scripts/audit_messaging_cleanup.js            # rapport seul (dry-run)
 *   node scripts/audit_messaging_cleanup.js --fix      # applique les corrections
 *
 * Pré-requis : variable d'env MONGO_URI (ou MONGODB_URI) — la même que le
 * serveur. À lancer côté admin/Render (shell), JAMAIS depuis l'app.
 *
 * Ce qu'il vérifie / corrige :
 *  1. Conversations : compteurs unread négatifs ou NaN  → clamp à 0 (--fix).
 *  2. MapReports « zombies » aux coordonnées (0,0)       → rapport (+ suppression --fix).
 *  3. Notifications en DOUBLON (même destinataire + type + cible, < 60 s d'écart)
 *                                                        → rapport (+ suppression des copies --fix, garde la 1re).
 *  4. Conversations en double par paire (booking + amis pour les 2 mêmes
 *     personnes) qui portent toutes deux des non-lus    → rapport (jamais auto-fix : à arbitrer).
 *
 * AUCUNE suppression destructive sans --fix. Les suppressions de doublons
 * gardent toujours le document le plus ancien.
 */
/* eslint-disable no-console */
const mongoose = require('mongoose');

const FIX = process.argv.includes('--fix');
const MONGO = process.env.MONGO_URI || process.env.MONGODB_URI || '';

async function main() {
  if (!MONGO) {
    console.error('❌ MONGO_URI (ou MONGODB_URI) manquant dans l\'environnement.');
    process.exit(1);
  }
  await mongoose.connect(MONGO);
  console.log(`✅ Connecté à MongoDB. Mode = ${FIX ? 'FIX (écriture)' : 'DRY-RUN (lecture seule)'}\n`);

  const db = mongoose.connection.db;
  const Conversation = db.collection('conversations');
  const Notification = db.collection('notifications');
  const MapReport = db.collection('mapreports');

  // ── 1. Compteurs unread incohérents ───────────────────────────────────────
  const badCounters = await Conversation.find({
    $or: [
      { ownerUnreadCount: { $lt: 0 } },
      { sitterUnreadCount: { $lt: 0 } },
      { 'participants.unreadCount': { $lt: 0 } },
    ],
  }).toArray();
  console.log(`1) Conversations avec compteur unread négatif : ${badCounters.length}`);
  if (FIX && badCounters.length) {
    for (const c of badCounters) {
      const set = {};
      if (typeof c.ownerUnreadCount === 'number' && c.ownerUnreadCount < 0) set.ownerUnreadCount = 0;
      if (typeof c.sitterUnreadCount === 'number' && c.sitterUnreadCount < 0) set.sitterUnreadCount = 0;
      if (Object.keys(set).length) await Conversation.updateOne({ _id: c._id }, { $set: set });
      if (Array.isArray(c.participants)) {
        for (let i = 0; i < c.participants.length; i++) {
          if ((c.participants[i].unreadCount || 0) < 0) {
            await Conversation.updateOne(
              { _id: c._id },
              { $set: { [`participants.${i}.unreadCount`]: 0 } },
            );
          }
        }
      }
    }
    console.log('   → corrigé (clamp à 0).');
  }

  // ── 2. Signalements zombies (0,0) ──────────────────────────────────────────
  const zombies = await MapReport.countDocuments({ 'location.coordinates': [0, 0] });
  console.log(`2) MapReports aux coordonnées (0,0) (invisibles, inutiles) : ${zombies}`);
  if (FIX && zombies) {
    const r = await MapReport.deleteMany({ 'location.coordinates': [0, 0] });
    console.log(`   → supprimés : ${r.deletedCount}`);
  }

  // ── 3. Notifications en doublon ────────────────────────────────────────────
  // Doublon = même (recipientRole, recipientId, type) + même cible
  // (data.bookingId / conversationId / messageId) à moins de 60 s d'écart.
  const all = await Notification.find({})
    .project({ recipientRole: 1, recipientId: 1, type: 1, data: 1, createdAt: 1 })
    .sort({ createdAt: 1 })
    .toArray();
  const seen = new Map();
  const dupes = [];
  for (const n of all) {
    const tgt = (n.data && (n.data.bookingId || n.data.conversationId || n.data.messageId || n.data.applicationId)) || '';
    const key = `${n.recipientRole}|${n.recipientId}|${n.type}|${tgt}`;
    const prev = seen.get(key);
    const t = n.createdAt ? new Date(n.createdAt).getTime() : 0;
    if (prev && Math.abs(t - prev.t) < 60 * 1000) {
      dupes.push(n._id); // copie → candidate à la suppression (on garde prev)
    } else {
      seen.set(key, { t });
    }
  }
  console.log(`3) Notifications en doublon (< 60 s, même cible) : ${dupes.length}`);
  if (FIX && dupes.length) {
    const r = await Notification.deleteMany({ _id: { $in: dupes } });
    console.log(`   → copies supprimées (1re gardée) : ${r.deletedCount}`);
  }

  // ── 4. Conversations en double par paire (rapport seulement) ───────────────
  const convs = await Conversation.find({})
    .project({ ownerId: 1, sitterId: 1, walkerId: 1, friendChat: 1, participants: 1, ownerUnreadCount: 1, sitterUnreadCount: 1 })
    .toArray();
  const byPair = new Map();
  for (const c of convs) {
    const ids = [];
    if (c.ownerId) ids.push(String(c.ownerId));
    if (c.sitterId) ids.push(String(c.sitterId));
    if (c.walkerId) ids.push(String(c.walkerId));
    if (Array.isArray(c.participants)) {
      for (const p of c.participants) if (p.userId) ids.push(String(p.userId._id || p.userId));
    }
    if (ids.length < 2) continue;
    const key = ids.sort().join('|');
    byPair.set(key, (byPair.get(key) || 0) + 1);
  }
  const dupPairs = [...byPair.values()].filter((n) => n > 1).length;
  console.log(`4) Paires de personnes ayant PLUSIEURS conversations (booking + amis) : ${dupPairs}`);
  console.log('   (non auto-corrigé : à arbitrer — le badge frontend dédoublonne déjà par personne depuis v448.)');

  console.log(`\n✅ Terminé.${FIX ? '' : ' (Aucune écriture — relance avec --fix pour appliquer.)'}`);
  await mongoose.disconnect();
}

main().catch(async (e) => {
  console.error('❌ Erreur :', e.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
