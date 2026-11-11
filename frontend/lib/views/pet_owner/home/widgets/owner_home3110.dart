// PAM-B 31/10/2026 — accueil propriétaire, contenu sous le hero (maquette
// `Accueil Owner v3.dc.html`). DESIGN UNIQUEMENT : chaque bouton reçoit le
// callback que l'écran branchait déjà (« Faire garder », « Faire promener »,
// onglets, « Publier mon annonce »).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';

/// Les 2 cartes services « Garde » (bleu) / « Promenade » (vert).
class ServiceCards3110 extends StatelessWidget {
  const ServiceCards3110({
    super.key,
    required this.onSitting,
    required this.onWalking,
    required this.sittingSubtitle,
    required this.walkingSubtitle,
    this.compact = false,
  });

  final VoidCallback onSitting;
  final VoidCallback onWalking;
  final String sittingSubtitle;
  final String walkingSubtitle;

  /// Version basse dès qu'une annonce existe (comportement 571 conservé).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ServiceCard3110(
            key: const ValueKey<String>('owner_card_sitting'),
            title: 'pamb3110_card_sitting'.tr,
            subtitle: sittingSubtitle,
            icon: Icons.home_outlined,
            start: const Color(0xFF3B6FE0),
            end: const Color(0xFF2457C5),
            shadow: const Color(0x472457C5),
            compact: compact,
            onTap: onSitting,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ServiceCard3110(
            key: const ValueKey<String>('owner_card_walking'),
            title: 'pamb3110_card_walking'.tr,
            subtitle: walkingSubtitle,
            icon: Icons.directions_walk_rounded,
            start: const Color(0xFF2BB35E),
            end: const Color(0xFF1F9A4B),
            shadow: const Color(0x471F9A4B),
            compact: compact,
            onTap: onWalking,
          ),
        ),
      ],
    );
  }
}

class ServiceCard3110 extends StatelessWidget {
  const ServiceCard3110({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.start,
    required this.end,
    required this.shadow,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color start;
  final Color end;
  final Color shadow;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget arrow = Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Icon(Icons.north_east_rounded, size: 15, color: end),
    );
    final Widget tile = Container(
      width: compact ? 36 : 48,
      height: compact ? 36 : 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
      ),
      child: Icon(icon, size: compact ? 20 : 24, color: Colors.white),
    );
    final Widget titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: pop3110(
        fontSize: compact ? 15 : 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.15,
      ),
    );
    final Widget subText = Text(
      subtitle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: pop3110(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.85),
        height: 1.25,
      ),
    );

    return Semantics(
      button: true,
      label: subtitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 76 : 150),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: const Alignment(-0.34, -1),
                end: const Alignment(0.34, 1),
                colors: <Color>[start, end],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: -50,
                  right: -40,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    compact ? 12 : 16,
                    compact ? 12 : 16,
                    compact ? 12 : 14,
                  ),
                  child: compact
                      ? Row(
                          children: <Widget>[
                            tile,
                            const SizedBox(width: 10),
                            // 631 (ZOE) : en version basse, le titre seul,
                            // réduit s'il le faut — « Prome… » / « Faire
                            // garder m… » étaient coupés sur iPhone 16.
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: titleText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            arrow,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[tile, arrow],
                            ),
                            const SizedBox(height: 18),
                            titleText,
                            const SizedBox(height: 2),
                            subText,
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips filtres : « Mes annonces (N) » / « Pet-sitters » / « Promeneurs ».
class FilterChips3110 extends StatelessWidget {
  const FilterChips3110({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
    required this.myCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 3 libellés, dans l'ordre des onglets.
  final List<String> labels;
  final int myCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final bool active = i == selectedIndex;
          return _Chip3110(
            key: ValueKey<String>('owner_chip_$i'),
            label: labels[i],
            active: active,
            count: i == 0 ? myCount : null,
            onTap: () => onSelected(i),
          );
        },
      ),
    );
  }
}

class _Chip3110 extends StatelessWidget {
  const _Chip3110({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final bool dark = HomeTokens3110.isDark(context);
    final Color bg = active
        ? (dark ? Colors.white : HomeTokens3110.ink)
        : HomeTokens3110.card(context);
    final Color fg = active
        ? (dark ? HomeTokens3110.ink : Colors.white)
        : (dark ? HomeTokens3110.text(context) : HomeTokens3110.chipInk);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: active || dark
                ? null
                : const <BoxShadow>[
                    BoxShadow(color: Color(0x0F1C1917), spreadRadius: 1),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                style: pop3110(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.2,
                ),
              ),
              if (count != null) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: HomeTokens3110.owner.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: pop3110(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte état vide « Ta première annonce en 1 minute » (3 étapes + CTA).
class FirstPostCard3110 extends StatelessWidget {
  const FirstPostCard3110({
    super.key,
    required this.title,
    required this.steps,
    required this.ctaLabel,
    required this.onCta,
  });

  final String title;
  final List<String> steps;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    const HomeTokens3110 t = HomeTokens3110.owner;
    return Container(
      key: const ValueKey<String>('owner_first_post_card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomeTokens3110.card(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: t.cardShadow(context),
      ),
      // 635 (Daniel 03/11) — plus de rond décoratif coupé dans le coin, et
      // hauteur naturelle (la colonne n'est plus étirée).
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x4DC62817),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: pop3110(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: HomeTokens3110.text(context),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'pamb3110_three_steps'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: pop3110(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: HomeTokens3110.text2(context),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 641 — le bouton passe JUSTE SOUS le titre (retour testeur :
                // en bas de la carte, le menu flottant le recouvrait au repos).
                // Les 3 étapes suivent, en dessous.
                const SizedBox(height: 14),
                PrimaryPill3110(
                  key: const ValueKey<String>('owner_first_post_cta'),
                  label: ctaLabel,
                  color: t.primary,
                  shadow: t.shadowColor,
                  onTap: onCta,
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < steps.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 9),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.tintOn(context),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: pop3110(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: t.primary,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          steps[i],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: pop3110(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: HomeTokens3110.text(context),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton primaire pill 48 px avec flèche →.
class PrimaryPill3110 extends StatelessWidget {
  const PrimaryPill3110({
    super.key,
    required this.label,
    required this.color,
    required this.shadow,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color shadow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 635 — l'ombre vit sur un DecoratedBox en pilule : posée dans un `Ink`,
    // elle se dessinait en rectangle rose derrière le bouton (vu au simulateur).
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: color,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pop3110(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
