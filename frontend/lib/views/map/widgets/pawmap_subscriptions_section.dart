// v585 (25/09/2026, bug 15) — Daniel : « l'option d'activer ou désactiver les
// abonnements sur la carte » ne se trouvait plus : trois pilules minuscules
// tout en bas de la feuille. Section claire « Mes abonnements sur la carte » :
// une ligne par abonnement (icône, nom, ce que ça active, interrupteur à la
// couleur de l'abonnement) ; abonnement non possédé → « Découvrir » (vers la
// boutique), jamais un interrupteur mort. L'état est celui des calques de la
// carte, déjà enregistrés sur le COMPTE (MapPrefsService, 3 profils).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../utils/pawmap_theme.dart';
import 'pawmap_buttons.dart';

class PawMapSubscriptionLine {
  const PawMapSubscriptionLine({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.owned,
    required this.on,
    required this.onToggle,
    required this.onDiscover,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool owned;
  final bool on;
  final VoidCallback onToggle;
  final VoidCallback onDiscover;
}

class PawMapSubscriptionsSection extends StatelessWidget {
  const PawMapSubscriptionsSection({super.key, required this.lines});

  final List<PawMapSubscriptionLine> lines;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    return Container(
      key: const ValueKey<String>('pawmap_subs_section'),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A1F1C) : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: PawMapTheme.borderOn(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 58.w,
                color: PawMapTheme.borderOn(context),
              ),
            _row(context, lines[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, PawMapSubscriptionLine l) {
    return Semantics(
      toggled: l.owned ? l.on : null,
      button: true,
      label: l.name,
      child: InkWell(
        key: ValueKey<String>('pawmap_sub_${l.id}'),
        borderRadius: BorderRadius.circular(18.r),
        onTap: l.owned ? l.onToggle : l.onDiscover,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(l.color, Colors.white, 0.15)!,
                      Color.lerp(l.color, Colors.black, 0.12)!,
                    ],
                  ),
                ),
                child: Icon(l.icon, color: Colors.white, size: 19.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name,
                        style: PawMapTheme.fontOn(context,
                            size: 13.5.sp, weight: FontWeight.w800)),
                    SizedBox(height: 1.h),
                    Text(l.subtitle,
                        maxLines: 2,
                        style: PawMapTheme.fontOn(context,
                            size: 11.sp,
                            weight: FontWeight.w500,
                            color: PawMapTheme.subOn(context))),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (l.owned)
                Switch.adaptive(
                  key: ValueKey<String>('pawmap_sub_switch_${l.id}'),
                  value: l.on,
                  activeTrackColor: l.color,
                  activeThumbColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Color.lerp(l.color, Colors.white, 0.72),
                  trackOutlineColor:
                      WidgetStatePropertyAll(Color.lerp(l.color, Colors.white, 0.4)),
                  onChanged: (_) => l.onToggle(),
                )
              else
                PawSignatureButton(
                  key: ValueKey<String>('pawmap_sub_discover_${l.id}'),
                  kind: PawButtonKind.secondary,
                  expand: false,
                  label: 'pawmap585_subs_discover'.tr,
                  color: l.color,
                  onTap: l.onDiscover,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
