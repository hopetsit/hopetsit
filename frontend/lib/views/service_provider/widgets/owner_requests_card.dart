// v586 (point 9 de Daniel, 25/09/2026) — carte « Demandes en cours » sur la
// fiche d'un PROPRIÉTAIRE vue par un gardien / promeneur : service, dates,
// animal, budget, ville · distance (jamais l'adresse exacte) et la
// candidature en UN appui (« Proposer mes services », bouton signature à la
// couleur du rôle du SPECTATEUR). Widget PUR : l'écran fournit les demandes,
// les états et le rappel.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/owner_active_request.dart';
import 'package:hopetsit/services/propose_services_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/map/widgets/pawmap_buttons.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/service_provider/widgets/public_profile_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

class OwnerRequestsCard extends StatelessWidget {
  const OwnerRequestsCard({
    super.key,
    required this.requests,
    required this.viewerRole,
    required this.states,
    required this.onPropose,
  });

  final List<OwnerActiveRequest> requests;

  /// 'sitter' | 'walker' — couleur du bouton (rôle du SPECTATEUR).
  final String viewerRole;
  final Map<String, OwnerRequestApplyState> states;
  final void Function(OwnerActiveRequest r) onPropose;

  @override
  Widget build(BuildContext context) {
    final Color accent = PawMapLegend.roleColor('owner');
    return PublicProfileSection(
      key: const ValueKey<String>('owner_requests_card'),
      accent: accent,
      icon: Icons.campaign_rounded,
      title: 'pawmap586b_requests_title'.tr,
      trailing: InterText(
        text: '${requests.length}',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < requests.length; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(height: 1, color: AppColors.divider(context)),
              ),
            _RequestTile(
              request: requests[i],
              viewerRole: viewerRole,
              state: states[requests[i].id] ?? applyStateFromServer(requests[i].myApplication),
              onPropose: () => onPropose(requests[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.viewerRole,
    required this.state,
    required this.onPropose,
  });

  final OwnerActiveRequest request;
  final String viewerRole;
  final OwnerRequestApplyState state;
  final VoidCallback onPropose;

  String _dates(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final s = request.startDate?.toLocal();
    final e = request.endDate?.toLocal();
    if (s == null && e == null) return '';
    if (s != null && e != null && !DateUtils.isSameDay(s, e)) {
      return '${loc.formatShortDate(s)} → ${loc.formatShortDate(e)}';
    }
    return loc.formatShortDate((s ?? e)!);
  }

  String get _service {
    if (request.serviceTypes.isEmpty) return 'pawmap586b_request_generic'.tr;
    return request.serviceTypes.map(translateServiceType).join(' · ');
  }

  String get _place {
    final String city = request.city.trim();
    final int? km = request.distanceKm;
    final String dist = km == null ? '' : 'pawmap586b_km'.trParams({'km': '$km'});
    if (city.isEmpty) return dist;
    return dist.isEmpty ? city : '$city · $dist';
  }

  @override
  Widget build(BuildContext context) {
    final Color color = PawMapLegend.roleColor(viewerRole);
    final String dates = _dates(context);
    final String pets = request.pets.map((p) => p.name.trim()).where((n) => n.isNotEmpty).join(', ');
    final String budget = request.budgetLabel;
    final String place = _place;

    final (String label, IconData icon, bool enabled) = switch (state) {
      OwnerRequestApplyState.sent => ('pawmap586b_sent'.tr, Icons.check_circle_rounded, false),
      OwnerRequestApplyState.already => ('pawmap586b_already'.tr, Icons.check_circle_rounded, false),
      OwnerRequestApplyState.accepted => ('pawmap586b_accepted'.tr, Icons.verified_rounded, false),
      OwnerRequestApplyState.rejected => ('pawmap586b_rejected'.tr, Icons.do_not_disturb_on_rounded, false),
      _ => ('pawmap586b_propose'.tr, Icons.send_rounded, true),
    };

    return Column(
      key: ValueKey<String>('owner_request_${request.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PoppinsText(
          text: _service,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          maxLines: 3,
        ),
        SizedBox(height: 6.h),
        if (dates.isNotEmpty) _line(context, Icons.event_rounded, dates),
        if (pets.isNotEmpty) _line(context, Icons.pets_rounded, pets),
        if (budget.isNotEmpty)
          _line(context, Icons.payments_rounded, 'pawmap586b_budget'.trParams({'amount': budget})),
        if (place.isNotEmpty) _line(context, Icons.place_rounded, place),
        SizedBox(height: 10.h),
        PawSignatureButton(
          key: ValueKey<String>('owner_request_propose_${request.id}'),
          label: label,
          icon: icon,
          color: color,
          kind: enabled ? PawButtonKind.primary : PawButtonKind.secondary,
          action: PawButtonAction.send,
          loading: state == OwnerRequestApplyState.busy,
          enabled: enabled || state == OwnerRequestApplyState.busy,
          onTap: enabled ? onPropose : null,
        ),
      ],
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16.sp, color: AppColors.accentOn(context, PawMapLegend.roleColor('owner'))),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryStrong(context),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
