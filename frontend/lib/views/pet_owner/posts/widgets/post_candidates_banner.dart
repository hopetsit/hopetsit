import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';

/// v23.1 — B3 : compact banner shown above an owner's post card when more
/// than one provider has applied. Tapping opens the candidates bottom sheet
/// where the owner can pick the right one.
///
/// v569 — le dégradé orange maison est remplacé par le gabarit UNIQUE des
/// bandeaux d'action (`ActionBanner`, ton « à traiter » ambre), pour que ce
/// bandeau parle le même langage que ceux de l'accueil et des réservations.
/// ⚠️ DESIGN UNIQUEMENT : même condition d'affichage (≥ 2 candidatures
/// `pending` sur CETTE annonce), même ouverture de `PostCandidatesSheet`.
class PostCandidatesBanner extends StatelessWidget {
  const PostCandidatesBanner({
    super.key,
    required this.postId,
  });

  final String postId;

  List<ApplicationModel> _pendingForPost(ApplicationsController c) {
    return c.applications
        .where((a) =>
            a.postId == postId && a.status.toLowerCase().trim() == 'pending')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<ApplicationsController>()
        ? Get.find<ApplicationsController>()
        : Get.put(ApplicationsController());

    return Obx(() {
      final pending = _pendingForPost(c);
      if (pending.length < 2) return const SizedBox.shrink();
      void open() => PostCandidatesSheet.show(
            context: context,
            postId: postId,
          );
      return ActionBanner(
        tone: ActionTone.pending,
        icon: Icons.groups_rounded,
        title: 'candidates_banner_title'
            .trParams({'count': pending.length.toString()}),
        subtitle: 'candidates_banner_subtitle'.tr,
        margin: EdgeInsets.only(bottom: 10.h),
        onTap: open,
        trailing: ActionPillButton(
          label: 'lists569_candidates_action'.tr,
          tone: ActionTone.pending,
          compact: true,
          maxWidth: 124.w,
          onPressed: open,
        ),
      );
    });
  }
}
