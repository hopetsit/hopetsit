const mongoose = require('mongoose');

/**
 * v23.1 part 146 — Bridge de session web → app via deep link.
 *
 * Flow :
 *   1. User logué sur hopetsit.com clique "Ouvrir dans l'app".
 *   2. Site appelle POST /auth/one-time-token (avec son JWT) → backend
 *      génère un token aléatoire 32 bytes, stocke son SHA-256 ici avec
 *      TTL 60s, et retourne le token brut au site.
 *   3. Site redirige le user vers `hopetsit://auth?ott=<token brut>`.
 *   4. L'app (DeepLinkService) intercepte le lien, extrait l'ott et
 *      appelle POST /auth/exchange { token: ott }.
 *   5. Backend hash le token reçu, cherche le doc correspondant, marque
 *      `used=true` (atomique via findOneAndUpdate), génère un NOUVEAU
 *      JWT 30j pour le user, et renvoie { token, role, user }.
 *   6. L'app stocke le JWT comme si l'user venait de se logger via
 *      /auth/login — il est désormais authentifié dans l'app.
 *
 * Sécurité :
 *   - On stocke uniquement le SHA-256, jamais le token brut.
 *   - TTL Mongo natif (`expires: 0` sur `expiresAt`) supprime
 *     automatiquement les docs périmés au bout de ~60s + 1min de
 *     grace de la part du sweeper Mongo.
 *   - Single-use : `findOneAndUpdate({ used: false }, { used: true })`
 *     est atomique, donc même si l'app double-tape le bouton on n'a
 *     qu'UN seul échange réussi.
 *   - Format token : 64 chars hex (32 bytes random), valide via regex
 *     côté controller AVANT toute query Mongo.
 */
const oneTimeTokenSchema = new mongoose.Schema(
  {
    // SHA-256 du token brut envoyé au client. Le token brut n'est
    // JAMAIS stocké en DB → un dump de la collection ne permet pas
    // de récupérer une session.
    tokenHash: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    // Owner._id / Sitter._id / Walker._id selon le rôle.
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
    },
    role: {
      type: String,
      enum: ['owner', 'sitter', 'walker'],
      required: true,
    },
    used: {
      type: Boolean,
      default: false,
      index: true,
    },
    // Index TTL : Mongo supprime auto le doc à expiresAt.
    // `expires: 0` = "supprime dès que la date est dépassée".
    expiresAt: {
      type: Date,
      required: true,
      index: { expires: 0 },
    },
    // Métadonnées audit (utile pour debug + détection abuse).
    issuedFromIp: { type: String },
    issuedUserAgent: { type: String },
  },
  { timestamps: true },
);

module.exports = mongoose.model('OneTimeToken', oneTimeTokenSchema);
