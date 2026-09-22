import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Champ de saisie commun à toute l'app (100+ écrans).
///
/// v569 — Daniel : « tout ce qui reste d'avant et pas touché : vérifie et
/// modernise ». RENDU SEULEMENT : l'API publique, les valeurs par défaut et
/// le câblage du `TextFormField` (controller, validator, onChanged, onSaved,
/// onTap, focusNode, inputFormatters, keyboardType, obscureText, enabled,
/// readOnly, maxLines/minLines/maxLength, textInputAction, errorText) sont
/// STRICTEMENT inchangés.
///
/// Ce qui change : surface claire, coins [radius] appliqués à TOUS les états
/// (avant, seul `border` suivait `radius` — `enabled`/`focused`/`error`
/// restaient figés à 14, donc un champ demandé en 16 rendait deux rayons
/// différents), bordure fine 1 px → 1,6 px couleur de marque au focus (animée
/// par `InputDecorator`), halo doux au focus, libellé 13/600 au-dessus,
/// message d'erreur 12 px rouge sur 2 lignes, hauteur tactile ≥ 52, état
/// désactivé lisible, bouton œil propre (avec libellé d'accessibilité traduit).
class CustomTextField extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final double radius;

  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;
  final void Function()? onTap;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool showPasswordToggle;
  final EdgeInsetsGeometry? contentPadding;

  const CustomTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.inputFormatters,
    this.errorText,
    this.showPasswordToggle = false,
    this.contentPadding,
      this.radius = 14,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = false;
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  /// Bordure d'un état donné — même rayon partout (celui demandé par l'appelant).
  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.radius.r),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasError = widget.errorText != null;

    // Surface : blanche en clair (façon Apple, lisible sur les fonds pâles
    // teintés par rôle), gris foncé en sombre. Désactivé = un cran plus terne
    // mais toujours lisible.
    final Color fill = !widget.enabled
        ? (isDark ? const Color(0xFF211715) : const Color(0xFFF8F4F3))
        : (isDark ? AppColors.inputFill(context) : Colors.white);
    final Color line = isDark ? AppColors.dividerDark : const Color(0xFFECE2DF);
    final Color textColor = widget.enabled
        ? AppColors.textPrimary(context)
        : AppColors.textSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          InterText(
            text: widget.labelText!,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
            letterSpacing: 0.1,
          ),
          SizedBox(height: 7.h),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius.r),
            boxShadow: _isFocused && widget.enabled && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                      spreadRadius: -1,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: _obscureText,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onSaved: widget.onSaved,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            cursorColor: AppColors.primaryColor,
            cursorWidth: 1.6,
            cursorRadius: const Radius.circular(2),
            style: GoogleFonts.inter(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            decoration: InputDecoration(
              isDense: true,
              constraints: BoxConstraints(minHeight: 52.h),
              hintText: widget.hintText,
              hintStyle: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                    : AppColors.grey500Color.withValues(alpha: 0.75),
              ),
              prefixIcon: widget.prefixIcon,
              prefixIconColor: _isFocused
                  ? AppColors.primaryColor
                  : AppColors.textSecondary(context),
              suffixIcon: widget.showPasswordToggle
                  ? IconButton(
                      splashRadius: 20.r,
                      tooltip: _obscureText
                          ? 'auth569_password_show'.tr
                          : 'auth569_password_hide'.tr,
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _isFocused
                            ? AppColors.primaryColor
                            : AppColors.textSecondary(context),
                        size: 21.sp,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : widget.suffixIcon,
              errorText: widget.errorText,
              errorMaxLines: 2,
              errorStyle: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.errorColor,
                height: 1.35,
              ),
              contentPadding:
                  widget.contentPadding ??
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              filled: true,
              fillColor: fill,
              border: _border(line, 1),
              enabledBorder: _border(line, 1),
              focusedBorder: _border(AppColors.primaryColor, 1.6),
              errorBorder: _border(AppColors.errorColor, 1.2),
              focusedErrorBorder: _border(AppColors.errorColor, 1.6),
              disabledBorder: _border(
                line.withValues(alpha: 0.6),
                1,
              ),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}
