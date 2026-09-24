// v565 — points 26/33 : kit UI partagé par la page Profil et TOUTES ses
// sous-pages (owner / sitter / walker). Style Apple minimaliste + « Paw
// Buttons » : cartes groupées à coins 20, sans bordure, ombre très douce,
// rangées séparées par un filet, chip d'icône teinté, chevron discret.
// La couleur du rôle est passée en `accent` (owner orange #C92A12, sitter
// bleu #2563EB, walker vert #16A34A).
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

/// Couleur d'accent d'un rôle (owner / sitter / walker).
Color profileAccentFor(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'sitter':
      return const Color(0xFF2563EB);
    case 'walker':
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFFC92A12);
  }
}

/// Couleur d'accent du rôle COURANT (lu dans GetStorage), pour les sous-pages
/// partagées par les 3 rôles.
Color currentRoleAccent() {
  try {
    return profileAccentFor(GetStorage().read<String>(StorageKeys.userRole));
  } catch (_) {
    return profileAccentFor('owner');
  }
}

/// Fond pâle d'un rôle (boutons larges, bandeaux).
Color profileAccentLightFor(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'sitter':
      return AppColors.scaffoldSitterLight;
    case 'walker':
      return AppColors.scaffoldWalkerLight;
    default:
      return AppColors.scaffoldOwnerLight;
  }
}

/// Titre de section (petites capitales grises), au-dessus d'un groupe.
class ProfileSectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;

  /// v578 — Daniel, 22/09 : « le petit haut-parleur animé » sur le profil.
  /// Le titre « SON » porte une icône de haut-parleur qui, avec ce drapeau,
  /// respire en continu et laisse partir des ondes. Discret : c'est un
  /// repère visuel, pas une animation qui attire l'œil.
  final bool animatedIcon;

  const ProfileSectionTitle(this.text,
      {super.key, this.icon, this.color, this.animatedIcon = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 18.h, bottom: 8.h, left: 6.w),
      child: Row(
        children: [
          if (icon != null) ...[
            animatedIcon
                ? LiveSpeakerIcon(
                    size: 16.sp,
                    color: color ?? AppColors.textSecondary(context))
                : Icon(icon,
                    size: 14.sp,
                    color: color ?? AppColors.textSecondary(context)),
            SizedBox(width: 6.w),
          ],
          Expanded(
            child: PoppinsText(
              text: text.toUpperCase(),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une rangée de menu (icône teintée + titre + sous-titre + chevron /
/// trailing). Utilisée DANS un [ProfileGroupCard].
class ProfileRow extends StatelessWidget {
  /// v585 (lot D) — [PawIcon] (famille maison) ou [IconData] (transition).
  final Object icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final bool danger;

  const ProfileRow({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    // v571 — audit mode sombre : les icônes de marque posées sur leur propre
    // teinte à 12 % s'enfoncent dans la carte sombre (#008000 ≈ 3:1,
    // #C92A12 ≈ 2,2:1). En sombre on éclaircit l'icône et on densifie un peu
    // la pastille. Le rendu clair est inchangé.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = danger
        ? (isDark
            ? Color.lerp(AppColors.errorColor, Colors.white, 0.35)!
            : AppColors.errorColor)
        : AppColors.textPrimary(context);
    final Color iconColor =
        isDark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Center(
                child: pawIconAny(icon,
                    size: 18.sp,
                    color: iconColor,
                    fill: iconColor.withValues(alpha: 0.18)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PoppinsText(
                    text: title,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    InterText(
                      text: subtitle!,
                      fontSize: 11.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: 8.w),
              trailing!,
            ] else if (showChevron && onTap != null)
              Icon(Icons.chevron_right_rounded,
                  size: 20.sp, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}

/// Carte blanche groupant plusieurs [ProfileRow] séparées par un filet.
class ProfileGroupCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  const ProfileGroupCard({super.key, required this.children, this.margin});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: 62.w,
          color: AppColors.divider(context).withValues(alpha: 0.6),
        ));
      }
    }
    return Container(
      margin: margin ?? EdgeInsets.only(bottom: 6.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// Grand bouton pâle (rôle) avec emoji/icône + libellé, 1 ligne.
class ProfileWideAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  const ProfileWideAction({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Get.isDarkMode;
    final labelColor = dark ? AppColors.textPrimary(context) : accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: dark ? accent.withValues(alpha: 0.18) : accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: accent.withValues(alpha: dark ? 0.35 : 0.28), width: 1.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.sp, color: labelColor),
            SizedBox(width: 8.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: InterText(
                  text: label,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scaffold commun des sous-pages du profil : barre claire, titre centré,
/// bouton retour couleur du rôle, corps défilant avec marge, bouton bas
/// optionnel (collé au-dessus de la barre système).
class ProfileSubPageScaffold extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget body;
  final Widget? bottom;
  final List<Widget>? actions;
  final bool scroll;
  final EdgeInsetsGeometry? padding;
  final Widget? floatingActionButton;

  const ProfileSubPageScaffold({
    super.key,
    required this.title,
    required this.accent,
    required this.body,
    this.bottom,
    this.actions,
    this.scroll = true,
    this.padding,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // v569 — le `SafeArea(top: false)` du corps n'applique RIEN sur le Samsung
    // de Daniel (`MediaQuery.padding.bottom` = 0 alors que la barre à 3 boutons
    // recouvre 48 px). On complète donc ici, avec un `context` pris AU-DESSUS
    // du SafeArea (celui de ce build) pour ne jamais compter l'inset deux fois.
    // Quand il y a une barre `bottom`, c'est elle qui porte le dégagement : le
    // contenu défilant n'a plus besoin de l'ajouter.
    final extraBottom = appBottomInsetInsideSafeArea(context);
    final content = scroll
        ? SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding ??
                EdgeInsets.fromLTRB(
                    16.w, 8.h, 16.w, 28.h + (bottom == null ? extraBottom : 0)),
            child: body,
          )
        : Padding(padding: padding ?? EdgeInsets.zero, child: body);
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: accent),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp, color: accent),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: PoppinsText(
          text: title,
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: actions,
      ),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        top: false,
        child: bottom == null
            ? content
            : Column(
                children: [
                  Expanded(child: content),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        16.w, 8.h, 16.w, 12.h + extraBottom),
                    child: bottom,
                  ),
                ],
              ),
      ),
        ),
    );
  }
}

/// Bouton principal plein (couleur du rôle), avec état chargement.
/// v585 (lot D) — rendu par le kit signature (`PawButton`) : dégradé
/// horizontal, disque blanc + icône, empreinte au toucher, libellé jamais
/// coupé. Même API, même action.
class ProfilePrimaryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool loading;
  final Object? icon;
  const ProfilePrimaryButton({
    super.key,
    required this.label,
    required this.accent,
    required this.onTap,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PawButton(
      label: label,
      onTap: onTap,
      color: accent,
      icon: icon,
      loading: loading,
      enabled: onTap != null,
      height: 52.h,
    );
  }
}

/// Bouton secondaire (contour du rôle, texte couleur du rôle).
class ProfileSecondaryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final Object? icon;
  const ProfileSecondaryButton({
    super.key,
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PawButton(
      label: label,
      onTap: onTap,
      color: accent,
      icon: icon,
      kind: PawButtonKind.secondary,
      enabled: onTap != null,
      height: 48.h,
    );
  }
}

/// État vide / erreur illustré (icône dans un disque teinté + titre +
/// message + action optionnelle).
class ProfileEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;

  const ProfileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = error ? AppColors.errorColor : accent;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32.sp, color: c),
            ),
            SizedBox(height: 14.h),
            PoppinsText(
              text: title,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            if (message != null && message!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              InterText(
                text: message!,
                fontSize: 13.sp,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
                maxLines: 4,
                height: 1.4,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 16.h),
              ProfileSecondaryButton(
                label: actionLabel!,
                accent: c,
                onTap: onAction,
                icon: error ? Icons.refresh_rounded : Icons.add_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'information teinté (icône + texte).
class ProfileInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;
  const ProfileInfoBanner({
    super.key,
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
              height: 1.4,
              maxLines: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de saisie « Apple » : libellé au-dessus, fond carte, coins 14.
class ProfileInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final Color accent;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final int? maxLength;
  final Widget? suffix;
  final Widget? prefix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  // v565 — point 39 : options ajoutées pour les sous-pages (masques de
  // saisie, champ « tap pour choisir » type date, focus).
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  const ProfileInput({
    super.key,
    required this.label,
    required this.controller,
    required this.accent,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    this.prefix,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          InterText(
            text: label,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 6.h),
        ],
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          focusNode: focusNode,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textSecondary(context).withValues(alpha: 0.8),
            ),
            filled: true,
            fillColor: AppColors.card(context),
            prefixIcon: prefix,
            suffixIcon: suffix,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: AppColors.divider(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: AppColors.divider(context)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: AppColors.divider(context).withValues(alpha: 0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: accent, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppColors.errorColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: AppColors.errorColor, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// Poignée de feuille modale (petite barre grise centrée).
class ProfileSheetHandle extends StatelessWidget {
  const ProfileSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        margin: EdgeInsets.only(top: 10.h, bottom: 14.h),
        decoration: BoxDecoration(
          color: AppColors.greyColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}

/// Ouvre une feuille modale « Apple » (fond scaffold, coins 24, clavier
/// respecté). `builder` reçoit le contexte de la feuille.
Future<T?> showProfileSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.scaffold(ctx),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        // v567 — Samsung edge-to-edge : l'inset bas vaut 0 alors que la barre
        // système couvre le bas de la feuille → 48 px réservés sur Android.
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.only(
            bottom: (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android &&
                    MediaQuery.of(ctx).viewInsets.bottom == 0)
                ? 48
                : 0,
          ),
          child: builder(ctx),
        ),
      ),
    ),
  );
}


/// v578 — Petit haut-parleur ANIMÉ du profil (Daniel, 22/09).
///
/// Boucle de 2,2 s : le cône respire de 4 % et deux ondes sortent l'une
/// après l'autre, en fondu. Tout est dessiné — aucune image, aucune police
/// d'icônes — pour que la couleur suive le rôle. L'animation se coupe si le
/// téléphone demande moins d'animations.
class LiveSpeakerIcon extends StatefulWidget {
  const LiveSpeakerIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<LiveSpeakerIcon> createState() => _LiveSpeakerIconState();
}

class _LiveSpeakerIconState extends State<LiveSpeakerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _LiveSpeakerPainter(
              color: widget.color,
              t: still ? 0.4 : _loop.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveSpeakerPainter extends CustomPainter {
  _LiveSpeakerPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint body = Paint()..color = color;

    final double breath = 1 + 0.04 * math.sin(t * 2 * math.pi);
    canvas.save();
    canvas.translate(w * 0.30, h / 2);
    canvas.scale(breath, breath);
    canvas.translate(-w * 0.30, -h / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.36, w * 0.16, h * 0.28),
        Radius.circular(w * 0.05),
      ),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.38)
        ..lineTo(w * 0.44, h * 0.16)
        ..lineTo(w * 0.44, h * 0.84)
        ..lineTo(w * 0.24, h * 0.62)
        ..close(),
      body,
    );
    canvas.restore();

    for (int i = 0; i < 2; i++) {
      final double phase = (t + i * 0.5) % 1.0;
      final double eased = Curves.easeOut.transform(phase);
      final double radius = w * (0.20 + 0.18 * eased);
      final double fade = (1 - phase).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.44, h / 2), radius: radius),
        -math.pi / 3.2,
        2 * math.pi / 3.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.085
          ..color = color.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_LiveSpeakerPainter old) =>
      old.t != t || old.color != color;
}
