// 628 (PAM, 29/10/2026) — bandeau « <Prénom> a candidaté à ta demande » +
// « Choisir <prénom> et payer · prix » dans la conversation du PROPRIÉTAIRE
// avec un gardien / promeneur qui a candidaté (parité site `/chat`, BOB
// 279333b5, `data-chat-choose-2910`). Données = `GET /applications/my`
// (candidature `pending` dont le prestataire = l'interlocuteur). Le bouton
// suit le MÊME parcours que le lien `?choose=1` de l'e-mail : feuille des
// candidats → encart « Réserver <prénom> ? » → paiement. Sans prix connu
// (dates à prévoir, tarif à venir) : « Voir sa candidature ».
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/dates620_candidates.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// La candidature EN ATTENTE de l'interlocuteur [contactId] (la plus
/// récente d'abord, dans l'ordre du serveur). Pure.
ApplicationModel? chatChooseApplication628(
    Iterable<ApplicationModel> applications, String contactId) {
  final id = contactId.trim();
  if (id.isEmpty) return null;
  for (final a in applications) {
    if (a.status.toLowerCase().trim() != 'pending') continue;
    if (a.sitter.id == id) return a;
  }
  return null;
}

/// Prix connu et juste (frais compris, serveur) → « Choisir … et payer ·
/// prix » ; sinon « Voir sa candidature ». Pure.
bool chatChoosePayable628(ApplicationModel app) =>
    !applicationIsStale620(app) &&
    !applicationIsIndicative620(app) &&
    candidateTotal2610(app).isNotEmpty;

/// Libellé du bouton. Pure.
String chatChooseLabel628(ApplicationModel app) {
  final name = app.sitter.name.isNotEmpty ? app.sitter.name : 'provider_unknown'.tr;
  final first = name.split(' ').first;
  if (chatChoosePayable628(app)) {
    return '${'cand627_fast_cta'.tr.replaceAll('{name}', first)} · ${candidateTotal2610(app)}';
  }
  return 'cand628_chat_see'.tr;
}

class ChatChooseBanner628 extends StatefulWidget {
  const ChatChooseBanner628({
    super.key,
    required this.conversationId,
    required this.conversations,
    this.onOpen,
  });

  final String conversationId;

  /// Liste réactive des conversations (pour retrouver l'interlocuteur).
  final Iterable<ChatConversationBase> Function() conversations;

  /// Test : remplace l'ouverture du parcours (défaut : DeepLinkService).
  final Future<void> Function(ApplicationModel app)? onOpen;

  @override
  State<ChatChooseBanner628> createState() => _ChatChooseBanner628State();
}

class _ChatChooseBanner628State extends State<ChatChooseBanner628> {
  bool _busy = false;

  ApplicationsController get _ctrl => Get.isRegistered<ApplicationsController>()
      ? Get.find<ApplicationsController>()
      : Get.put(ApplicationsController());

  @override
  void initState() {
    super.initState();
    // Candidatures fraîches à l'ouverture de la conversation (le serveur
    // 2910 renvoie les boostés d'abord ; une candidature peut dater de
    // quelques secondes).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _ctrl;
      if (!c.isLoading.value) c.loadApplications();
    });
  }

  Future<void> _open(ApplicationModel app) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.onOpen != null) {
        await widget.onOpen!(app);
      } else {
        await DeepLinkService.instance.openOwnerApplication628(app.id);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = AppColors.primaryColor;
    return Obx(() {
      final contactId =
          pawFollowContactId(widget.conversations(), widget.conversationId);
      final app = chatChooseApplication628(_ctrl.applications, contactId);
      if (app == null) return const SizedBox.shrink();
      final payable = chatChoosePayable628(app);
      final name =
          app.sitter.name.isNotEmpty ? app.sitter.name : 'provider_unknown'.tr;
      final first = name.split(' ').first;
      final bool dark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        key: const Key('chat628_choose'),
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
        decoration: BoxDecoration(
          // Site : fond #FFF6F2, liseré #F6D9CF ; sombre = teinte du rôle
          // sur la carte (jamais de gris).
          color: dark ? owner.withValues(alpha: 0.16) : const Color(0xFFFFF6F2),
          border: Border(
            bottom: BorderSide(
                color: dark ? owner.withValues(alpha: 0.45) : const Color(0xFFF6D9CF)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PoppinsText(
              key: const Key('chat628_title'),
              text: 'cand628_chat_title'.tr.replaceAll('{name}', first),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: dark ? AppColors.accentOn(context, owner) : const Color(0xFF9E1F0B),
              maxLines: 2,
            ),
            SizedBox(height: 8.h),
            ActionPillButton(
              key: const Key('chat628_cta'),
              label: chatChooseLabel628(app),
              icon: payable
                  ? Icons.account_balance_wallet_rounded
                  : Icons.visibility_rounded,
              tone: owner,
              expand: true,
              haptic: payable,
              busy: _busy,
              onPressed: () => _open(app),
            ),
            if (payable) ...[
              SizedBox(height: 5.h),
              Center(
                child: InterText(
                  key: const Key('chat628_escrow'),
                  text: 'cand628_g_escrow'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentOn(context, const Color(0xFF15803D)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
