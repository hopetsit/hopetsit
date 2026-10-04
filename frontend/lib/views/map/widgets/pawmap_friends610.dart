// 610 (PAM, 04/10/2026) — demandes d'amis et recherche de personnes sur la
// PawMap (Daniel : « si j'ai une demande d'ami, que je puisse aussi la voir sur
// la PawMap » ; « rechercher des amis sur la PawMap »). Design de BOB :
//   · pastille = nombre de demandes reçues sur le bouton Amis de la barre ;
//   · carte discrète sous la pilule Direct (une demande à la fois, refermable,
//     jamais rouverte dans la session une fois fermée) ;
//   · badge « demande d'ami » sur l'épingle de la personne si elle est visible ;
//   · la loupe cherche aussi les personnes : « Mes amis » (filtrage local),
//     « Membres » (GET /friends/search, 300 ms, 2 lettres minimum) et, champ
//     vide, les demandes reçues avec Accepter / Refuser.
// Accepter / Refuser = mêmes appels que l'écran Amis (FriendController).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

/// Rose « ami » de la légende (épingles des amis).
const Color kPm610Friend = Color(0xFFE0568B);
const Color kPm610FriendLight = Color(0xFFF06AA0);

/// État de la session : la carte « X veut être ton ami » fermée à la croix ne
/// revient pas avant le prochain lancement de l'app.
class PawFriendReqSession610 {
  PawFriendReqSession610._();
  static bool closed = false;

  /// Demandes déjà traitées depuis la carte (retirées tout de suite, sans
  /// attendre le rechargement de la liste).
  static final Set<String> handled = <String>{};

  static void resetForTests() {
    closed = false;
    handled.clear();
  }
}

/// La demande à montrer sur la carte (la plus ancienne non traitée), ou null.
Friendship? pawNextFriendRequest610(List<Friendship> incoming) {
  if (PawFriendReqSession610.closed) return null;
  for (final f in incoming) {
    if (f.other == null) continue;
    if (PawFriendReqSession610.handled.contains(f.id)) continue;
    return f;
  }
  return null;
}

/// Nombre de demandes reçues encore en attente (pastille du bouton Amis).
int pawPendingFriendRequests610(List<Friendship> incoming) => incoming
    .where((f) => f.other != null && !PawFriendReqSession610.handled.contains(f.id))
    .length;

/// Prénom affiché (« Camille D. » → « Camille »).
String pawFirstName610(String name) {
  final t = name.trim();
  if (t.isEmpty) return '';
  return t.split(RegExp(r'\s+')).first;
}

/// Minuscules sans accents, pour un filtrage tolérant (« élo » = « Elodie »).
String pawFold610(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

/// « Mes amis » : filtrage instantané sur le nom (chaque mot tapé doit se
/// retrouver dans le nom), sans appel réseau.
List<Friendship> pawFilterFriends610(List<Friendship> friends, String query) {
  final words = pawFold610(query.trim())
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const <Friendship>[];
  final out = <Friendship>[];
  for (final f in friends) {
    final o = f.other;
    if (o == null) continue;
    final n = pawFold610(o.name);
    if (words.every(n.contains)) out.add(f);
  }
  return out;
}

/// Membres trouvés par le serveur, sans les personnes déjà dans « Mes amis ».
List<Map<String, dynamic>> pawMembersNotFriends610(
    List<Map<String, dynamic>> members, List<Friendship> friends) {
  return members.where((m) {
    final id = (m['id'] ?? '').toString();
    return !friends.any((f) => f.other != null && f.other!.matchesId(id));
  }).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar rond (photo ou initiale), anneau rose.
// ─────────────────────────────────────────────────────────────────────────────

class _Pm610Avatar extends StatelessWidget {
  const _Pm610Avatar({required this.name, required this.url, this.size = 38, this.ring = kPm610Friend});
  final String name;
  final String url;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      color: ring.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Text(initial,
          style: PawMapTheme.fontOn(context,
              size: size * 0.42, weight: FontWeight.w800, color: ring)),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: ClipOval(
        child: url.startsWith('http')
            ? Image.network(url,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
            : fallback,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte discrète « X veut être ton ami · Accepter · Refuser »
// ─────────────────────────────────────────────────────────────────────────────

class PawFriendRequestCard610 extends StatelessWidget {
  const PawFriendRequestCard610({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    this.onClose,
    this.onOpen,
  });

  final Friendship request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  /// Croix (null = pas de croix, par ex. dans la liste de la loupe).
  final VoidCallback? onClose;

  /// Appui sur la photo / le nom.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final o = request.other!;
    final bool dark = PawMapTheme.isDark(context);
    final Color bg = dark ? PawMapTheme.panelDark : const Color(0xFFFFFCF8);
    return Material(
      key: ValueKey<String>('pm610_req_card_${request.id}'),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 6, 10),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kPm610FriendLight.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: kPm610Friend.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onOpen,
                  customBorder: const CircleBorder(),
                  child: _Pm610Avatar(name: o.name, url: o.avatar, size: 36),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    child: Text(
                      'pm610_req_wants'
                          .trParams(<String, String>{'name': pawFirstName610(o.name)}),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.fontOn(context, size: 12.5, weight: FontWeight.w700, height: 1.25),
                    ),
                  ),
                ),
                if (onClose != null)
                  Semantics(
                    button: true,
                    label: 'pm610_close'.tr,
                    child: InkWell(
                      key: const ValueKey<String>('pm610_req_close'),
                      customBorder: const CircleBorder(),
                      onTap: onClose,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPm610Friend.withValues(alpha: dark ? 0.35 : 0.14),
                            ),
                            child: Icon(Icons.close_rounded,
                                size: 13, color: dark ? Colors.white : kPm610Friend),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PawButton(
                    key: const ValueKey<String>('pm610_req_accept'),
                    label: 'pm610_accept'.tr,
                    icon: Icons.check_rounded,
                    color: kPm610Friend,
                    compact: true,
                    action: PawButtonAction.success,
                    onTap: onAccept,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PawButton(
                    key: const ValueKey<String>('pm610_req_decline'),
                    label: 'pm610_decline'.tr,
                    kind: PawButtonKind.secondary,
                    color: kPm610Friend,
                    compact: true,
                    onTap: onDecline,
                  ),
                ),
                if (onClose != null) const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recherche de personnes (loupe) : sections « Mes amis » puis « Membres »
// ─────────────────────────────────────────────────────────────────────────────

/// Titre de section de la feuille de recherche.
class PawSearchSectionTitle610 extends StatelessWidget {
  const PawSearchSectionTitle610(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
        child: Text(
          text,
          style: PawMapTheme.font(
            size: 11,
            weight: FontWeight.w800,
            color: PawMapTheme.subOn(context),
          ),
        ),
      );
}

/// Ligne « personne » (ami ou membre).
class PawPersonTile610 extends StatelessWidget {
  const PawPersonTile610({
    super.key,
    required this.name,
    required this.avatar,
    required this.subtitle,
    required this.onTap,
    this.ring = kPm610Friend,
    this.trailing,
  });

  final String name;
  final String avatar;
  final String subtitle;
  final VoidCallback onTap;
  final Color ring;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            _Pm610Avatar(name: name, url: avatar, size: 36, ring: ring),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.fontOn(context, size: 14, weight: FontWeight.w700)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PawMapTheme.fontOn(context,
                            size: 11, weight: FontWeight.w500, color: PawMapTheme.subOn(context))),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, size: 18, color: PawMapTheme.subOn(context)),
          ],
        ),
      ),
    );
  }
}

/// Couleur d'un rôle (propriétaire rouge, gardien bleu, promeneur vert).
Color pawRoleColor610(String role) {
  switch (role.toLowerCase()) {
    case 'sitter':
      return const Color(0xFF2563EB);
    case 'walker':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFFC92A12);
  }
}

/// Sections « Mes amis » (local) et « Membres » (serveur, 300 ms, ≥ 2 lettres).
class PawPeopleSearch610 extends StatefulWidget {
  const PawPeopleSearch610({
    super.key,
    required this.query,
    required this.friends,
    required this.searchMembers,
    required this.onFriendTap,
    required this.onMemberTap,
    this.memberOnMap,
    this.onMemberSeeOnMap,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String query;
  final List<Friendship> friends;
  final Future<List<Map<String, dynamic>>> Function(String q) searchMembers;
  final void Function(Friendship f) onFriendTap;
  final void Function(Map<String, dynamic> member) onMemberTap;

  /// Le membre est-il visible par tous sur la carte (position floutée) ?
  final bool Function(Map<String, dynamic> member)? memberOnMap;
  final void Function(Map<String, dynamic> member)? onMemberSeeOnMap;
  final Duration debounce;

  @override
  State<PawPeopleSearch610> createState() => _PawPeopleSearch610State();
}

class _PawPeopleSearch610State extends State<PawPeopleSearch610> {
  Timer? _timer;
  String _asked = '';
  bool _loading = false;
  List<Map<String, dynamic>> _members = const [];

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PawPeopleSearch610 old) {
    super.didUpdateWidget(old);
    if (old.query.trim() != widget.query.trim()) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final q = widget.query.trim();
    if (q.length < 2) {
      setStateSafe(() {
        _members = const [];
        _loading = false;
      });
      return;
    }
    _loading = true;
    _timer = Timer(widget.debounce, () async {
      _asked = q;
      List<Map<String, dynamic>> r = const [];
      try {
        r = await widget.searchMembers(q);
      } catch (_) {/* recherche indisponible : section vide */}
      if (!mounted || _asked != widget.query.trim()) return;
      setState(() {
        _members = r;
        _loading = false;
      });
    });
  }

  void setStateSafe(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim();
    if (q.length < 2) return const SizedBox.shrink();
    final friends = pawFilterFriends610(widget.friends, q);
    final members = pawMembersNotFriends610(_members, widget.friends);
    return Column(
      key: const ValueKey<String>('pm610_people'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (friends.isNotEmpty) ...[
          PawSearchSectionTitle610('pm610_my_friends'.tr,
              key: const ValueKey<String>('pm610_sec_friends')),
          for (final f in friends.take(6))
            PawPersonTile610(
              key: ValueKey<String>('pm610_friend_${f.id}'),
              name: f.other!.name,
              avatar: f.other!.avatar,
              subtitle: f.other!.city,
              onTap: () => widget.onFriendTap(f),
            ),
        ],
        if (_loading || members.isNotEmpty) ...[
          PawSearchSectionTitle610('pm610_members'.tr,
              key: const ValueKey<String>('pm610_sec_members')),
          if (_loading && members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PawMapTheme.accent),
                ),
              ),
            ),
          for (final m in members.take(8))
            PawPersonTile610(
              key: ValueKey<String>('pm610_member_${m['id']}'),
              name: (m['name'] ?? '').toString(),
              avatar: (m['avatar'] ?? '').toString(),
              subtitle: (m['city'] ?? '').toString(),
              ring: pawRoleColor610((m['role'] ?? '').toString()),
              onTap: () => widget.onMemberTap(m),
              trailing: (widget.memberOnMap?.call(m) ?? false) &&
                      widget.onMemberSeeOnMap != null
                  ? Semantics(
                      button: true,
                      label: 'pm610_see_on_map'.tr,
                      child: InkWell(
                        key: ValueKey<String>('pm610_see_${m['id']}'),
                        customBorder: const CircleBorder(),
                        onTap: () => widget.onMemberSeeOnMap!(m),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.map_rounded,
                              size: 20, color: PawMapTheme.toneOn(context, PawMapTheme.accent)),
                        ),
                      ),
                    )
                  : null,
            ),
        ],
        if (!_loading && friends.isEmpty && members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text('pm610_no_people'.tr,
                style: PawMapTheme.fontOn(context,
                    size: 12, weight: FontWeight.w600, color: PawMapTheme.subOn(context))),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge « demande d'ami » posé sur l'épingle (dessiné sur un canvas)
// ─────────────────────────────────────────────────────────────────────────────

/// Taille logique du badge (px).
const double kPm610BadgeSize = 26;

/// Badge rose rond, liseré blanc, silhouette + « + » blancs.
void paintFriendRequestBadge610(Canvas c, {double size = kPm610BadgeSize}) {
  final double r = size / 2 - 1.5;
  final Offset ctr = Offset(size / 2, size / 2);
  c.drawCircle(ctr.translate(0, 1.2), r,
      Paint()..color = kPm610Friend.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  c.drawCircle(
      ctr,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPm610FriendLight, kPm610Friend],
        ).createShader(Rect.fromCircle(center: ctr, radius: r)));
  c.drawCircle(ctr, r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.8);
  final white = Paint()..color = Colors.white;
  final double u = size / 26;
  // Silhouette (tête + épaules), un peu à gauche.
  c.drawCircle(Offset(10.2 * u, 10.0 * u), 3.0 * u, white);
  final body = Path()
    ..moveTo(4.8 * u, 18.6 * u)
    ..quadraticBezierTo(10.2 * u, 11.6 * u, 15.6 * u, 18.6 * u)
    ..close();
  c.drawPath(body, white);
  // « + » à droite.
  final plus = Paint()
    ..color = Colors.white
    ..strokeWidth = 2.0 * u
    ..strokeCap = StrokeCap.round;
  c.drawLine(Offset(19.4 * u, 9.4 * u), Offset(19.4 * u, 15.4 * u), plus);
  c.drawLine(Offset(16.4 * u, 12.4 * u), Offset(22.4 * u, 12.4 * u), plus);
}

/// Ancre du badge pour qu'il se pose à GAUCHE du rond (centre du rond = point
/// de la carte, rayon [ringR] px) : jamais sur la couronne (en haut), la coche
/// (en bas à droite) ni le point en ligne (en haut à gauche).
Offset pawFriendBadgeAnchor610(double ringR, {double size = kPm610BadgeSize}) {
  final double dx = -(ringR + size * 0.32);
  const double dy = 4;
  return Offset(0.5 - dx / size, 0.5 - dy / size);
}

/// Pastille du bouton Amis de la barre : nombre de demandes reçues.
class PawFriendReqCountBadge610 extends StatelessWidget {
  const PawFriendReqCountBadge610({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '${'pm610_req_section'.tr} : $count',
        child: Container(
          key: const ValueKey<String>('pm610_rail_badge'),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD62B4B),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            count > 99 ? '99+' : '$count',
            style: PawMapTheme.font(size: 10.5, weight: FontWeight.w800, color: Colors.white),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Patte du menu au contour VERT (≥ 1 ami en direct) — Daniel, 04/10 : « quand
// le pin est vert et que je clique dessus, ça me propose les amis en direct ;
// je clique sur l'un et ça zoome sur lui ».
// ─────────────────────────────────────────────────────────────────────────────

enum PawTabLiveAction610 { none, focusOne, showList }

/// Que fait l'appui sur la patte du menu ?
///   · contour blanc (personne en direct) ou rouge (mon direct perdu) : rien
///     de nouveau ;
///   · déjà sur l'onglet PawMap : la liste « En direct maintenant » ;
///   · un autre écran vient de demander la carte (chat, lien) : il passe avant ;
///   · UN ami en direct, jamais lâché : la carte file sur lui ;
///   · sinon (plusieurs, ou l'unique a été lâché) : la liste — c'est moi qui
///     choisis, personne n'est suivi d'office.
PawTabLiveAction610 pawTabLiveAction610({
  required int liveCount,
  required bool myLiveLost,
  required bool onPawMapTab,
  required bool explicitNow,
  required bool singleDeclined,
}) {
  if (liveCount <= 0 || myLiveLost) return PawTabLiveAction610.none;
  if (onPawMapTab) return PawTabLiveAction610.showList;
  if (explicitNow) return PawTabLiveAction610.none;
  if (liveCount == 1 && !singleDeclined) return PawTabLiveAction610.focusOne;
  return PawTabLiveAction610.showList;
}

/// Une ligne de la feuille « En direct maintenant ».
class PawLiveNowEntry610 {
  const PawLiveNowEntry610({
    required this.id,
    required this.name,
    this.avatar = '',
    this.role = 'owner',
    this.since,
    this.lost = false,
  });
  final String id;
  final String name;
  final String avatar;
  final String role;
  final DateTime? since;
  final bool lost;
}

/// « en balade · 12 min » (ou « en balade » sans heure de départ connue).
String pawLiveNowSubtitle610(PawLiveNowEntry610 e, {DateTime? now}) {
  if (e.lost) return 'pm610_lost'.tr;
  final s = e.since;
  if (s == null) return 'pm610_walking'.tr;
  final m = (now ?? DateTime.now()).difference(s).inMinutes;
  return 'pm610_walking_for'.trParams(<String, String>{'min': '${m < 1 ? 1 : m}'});
}

/// Feuille « En direct maintenant » : photo, prénom, « en balade · 12 min ».
class PawLiveNowSheet610 extends StatelessWidget {
  const PawLiveNowSheet610({super.key, required this.entries, required this.onPick, this.now});
  final List<PawLiveNowEntry610> entries;
  final void Function(PawLiveNowEntry610 e) onPick;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    return Container(
      key: const ValueKey<String>('pm610_live_now_sheet'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: dark ? PawMapTheme.panelDark : const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3FA33A).withValues(alpha: 0.5), width: 1.2),
        boxShadow: PawMapTheme.pillShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3FA33A).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('pm610_live_now'.tr,
                style: PawMapTheme.fontOn(context, size: 16, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final e in entries)
                  PawPersonTile610(
                    key: ValueKey<String>('pm610_live_${e.id}'),
                    name: e.name,
                    avatar: e.avatar,
                    subtitle: pawLiveNowSubtitle610(e, now: now),
                    ring: e.lost ? const Color(0xFFE8920A) : const Color(0xFF16A34A),
                    onTap: () => onPick(e),
                    trailing: const Icon(Icons.near_me_rounded, size: 18, color: Color(0xFF7C3AED)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
