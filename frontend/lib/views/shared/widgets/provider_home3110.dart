// PAM-B 31/10/2026 — accueil gardien / promeneur, cartes sous le hero
// (maquettes `Accueil Gardien.dc.html` / `Accueil Promeneur.dc.html`).
// DESIGN UNIQUEMENT : le curseur garde la logique de `AroundMeSearchBar`
// (valeur locale pendant le glissement, `onRadiusCommit` au relâchement).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/shared/widgets/home_hero3110.dart';
import 'package:hopetsit/views/shared/widgets/home640_kit.dart';

/// Carte « Rayon de recherche » : label + valeur, curseur, bornes.
class RadiusCard3110 extends StatefulWidget {
  const RadiusCard3110({
    super.key,
    required this.tokens,
    required this.radiusKm,
    required this.minRadiusKm,
    required this.maxRadiusKm,
    required this.onRadiusChanged,
    required this.onRadiusCommit,
  });

  final HomeTokens3110 tokens;
  final double radiusKm;
  final double minRadiusKm;
  final double maxRadiusKm;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<double> onRadiusCommit;

  @override
  State<RadiusCard3110> createState() => _RadiusCard3110State();
}

class _RadiusCard3110State extends State<RadiusCard3110> {
  double? _dragKm;
  double get _min => widget.minRadiusKm;
  double get _max => widget.maxRadiusKm;
  double _snap(double v) => v.clamp(_min, _max).roundToDouble();

  @override
  Widget build(BuildContext context) {
    final HomeTokens3110 t = widget.tokens;
    final double current = _snap(_dragKm ?? widget.radiusKm);
    return Container(
      key: const ValueKey<String>('provider_radius_card'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: HomeTokens3110.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: t.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'pamb3110_radius_title'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pop3110(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: HomeTokens3110.isDark(context)
                        ? HomeTokens3110.text2(context)
                        : HomeTokens3110.chipInk,
                  ),
                ),
              ),
              Text(
                '${current.round()} km',
                key: const ValueKey<String>('around_me_radius_value'),
                style: pop3110(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.primary,
                  height: 1.3,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: t.primary,
              inactiveTrackColor: t.tintOn(context),
              thumbColor: t.primary,
              overlayColor: t.primary.withValues(alpha: 0.12),
              thumbShape: _RingThumb3110(color: t.primary),
              trackShape: const RoundedRectSliderTrackShape(),
              // Maquette : piste lisse, pas de graduations intermédiaires.
              tickMarkShape: SliderTickMarkShape.noTickMark,
              valueIndicatorColor: t.primary,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: SizedBox(
              height: 34,
              child: Slider(
              key: const ValueKey<String>('around_me_radius_slider'),
              value: current,
              min: _min,
              max: _max,
              divisions: ((_max - _min) ~/ 10),
              label: '${current.round()} km',
              onChanged: (double value) {
                final double v = _snap(value);
                if (v != _dragKm) setState(() => _dragKm = v);
                widget.onRadiusChanged(v);
              },
              onChangeEnd: (double value) {
                final double v = _snap(value);
                setState(() => _dragKm = null);
                widget.onRadiusCommit(v);
              },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${_min.round()} km',
                style: pop3110(fontSize: 11, height: 1.2, color: HomeTokens3110.text3(context)),
              ),
              Text(
                '${_max.round()} km',
                style: pop3110(fontSize: 11, height: 1.2, color: HomeTokens3110.text3(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Poignée 22 px : disque couleur + anneau blanc 4 px + ombre.
class _RingThumb3110 extends SliderComponentShape {
  const _RingThumb3110({required this.color});
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas c = context.canvas;
    c.drawCircle(
      center + const Offset(0, 2),
      11,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    c.drawCircle(center, 11, Paint()..color = Colors.white);
    c.drawCircle(center, 7, Paint()..color = color);
  }
}

/// Carte « Ramène tes clients » (rendu seul ; `onShare` / `onQr` = mêmes
/// actions que la carte 607).
class BringClientsCard3110 extends StatelessWidget {
  const BringClientsCard3110({
    super.key,
    required this.tokens,
    required this.title,
    required this.body,
    required this.shareLabel,
    required this.qrLabel,
    required this.onShare,
    required this.onQr,
    this.badge,
  });

  final HomeTokens3110 tokens;
  final String title;
  final String body;
  final String shareLabel;
  final String qrLabel;
  final VoidCallback onShare;
  final VoidCallback onQr;
  /// Pastille « Pionnier » optionnelle (au-dessus du titre).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final HomeTokens3110 t = tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: HomeTokens3110.card(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: t.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (badge != null) ...<Widget>[badge!, const SizedBox(height: 10)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.tintOn(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_add_alt_1_outlined, size: 20, color: t.primary),
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
                      body,
                      maxLines: 3,
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
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PillButton3110(
                  key: const ValueKey<String>('neo607_home_share'),
                  label: shareLabel,
                  icon: Icons.ios_share_rounded,
                  filled: true,
                  tokens: t,
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillButton3110(
                  key: const ValueKey<String>('neo607_home_more'),
                  label: qrLabel,
                  icon: Icons.qr_code_2_rounded,
                  filled: false,
                  tokens: t,
                  onTap: onQr,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bouton pill 42 px : plein (primaire, blanc, ombre) ou teinté (texte primaire).
class PillButton3110 extends StatelessWidget {
  const PillButton3110({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    required this.tokens,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool filled;
  final HomeTokens3110 tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = filled ? Colors.white : tokens.primary;
    // 640 — le bouton plein porte le dégradé du rôle (maquettes de Daniel) ;
    // `kProviderHome640 = false` → aplat `tokens.primary` d'avant.
    final bool gradient640 = kProviderHome640 && filled;
    final List<BoxShadow> shadow = <BoxShadow>[
      BoxShadow(
        color: tokens.shadowColor,
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
    final Widget pill = Material(
      color: gradient640
          ? Colors.transparent
          : (filled ? tokens.primary : tokens.tintOn(context)),
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: gradient640
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[tokens.heroStart, tokens.heroEnd],
                )
              : null,
          // 640 : l'ombre est portée par l'enveloppe ci-dessous. Posée sur
          // l'`Ink`, elle est rognée au rectangle du `Material` (coins pâles
          // carrés autour de la pilule, vus sur la capture).
          boxShadow: filled && !gradient640 ? shadow : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pop3110(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!gradient640) return pill;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: shadow,
      ),
      child: pill,
    );
  }
}

/// Carte « C'est calme autour de toi » : en-tête + bouton rafraîchir rond +
/// 3 lignes d'action (profil / inviter / boutique).
class QuietCard3110 extends StatelessWidget {
  const QuietCard3110({
    super.key,
    required this.tokens,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.rows,
  });

  final HomeTokens3110 tokens;
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  final List<QuietRow3110> rows;

  @override
  Widget build(BuildContext context) {
    final HomeTokens3110 t = tokens;
    return Container(
      key: const ValueKey<String>('provider_quiet_card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomeTokens3110.card(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: t.cardShadow(context),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.tintDecoOn(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
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
                            subtitle,
                            maxLines: 2,
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
                    const SizedBox(width: 10),
                    Material(
                      color: t.tintOn(context),
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const ValueKey<String>('home_empty_refresh'),
                        customBorder: const CircleBorder(),
                        onTap: onRefresh,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.refresh_rounded, size: 18, color: t.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < rows.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 6),
                  _QuietRowTile(tokens: t, row: rows[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuietRow3110 {
  const QuietRow3110({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Key key;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuietRowTile extends StatelessWidget {
  const _QuietRowTile({required this.tokens, required this.row});
  final HomeTokens3110 tokens;
  final QuietRow3110 row;

  @override
  Widget build(BuildContext context) {
    final bool dark = HomeTokens3110.isDark(context);
    return Material(
      key: row.key,
      color: dark ? tokens.tintDecoOn(context) : tokens.pageBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: row.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HomeTokens3110.card(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(row.icon, size: 17, color: tokens.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pop3110(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: HomeTokens3110.text(context),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      row.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: pop3110(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: HomeTokens3110.text2(context),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18, color: HomeTokens3110.chevron),
            ],
          ),
        ),
      ),
    );
  }
}
