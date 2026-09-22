// v565 — ouverture d'une pièce jointe : photo plein écran (photo_view),
// vidéo dans le lecteur du téléphone (url_launcher — `video_player` n'est
// pas une dépendance du projet, voir « Écarts » du rapport).
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/utils/app_colors.dart';

Future<void> openChatMedia(BuildContext context, ChatAttachment a) async {
  if (a.isVideo) {
    final uri = Uri.tryParse(a.url);
    var ok = false;
    if (uri != null && a.localPath == null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) {
      CustomSnackbar.showWarning(
        title: 'cs_kind_video'.tr,
        message: 'cs_video_cannot_open'.tr,
      );
    }
    return;
  }
  if (a.isAudio) return;
  final provider = a.localPath != null
      ? FileImage(File(a.localPath!)) as ImageProvider
      : CachedNetworkImageProvider(a.url);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, size: 24.sp),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: PhotoView(
          imageProvider: provider,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          loadingBuilder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        ),
        ),
      ),
    ),
  );
}
