// v565 — avatar rond du chat + pastille de présence (point 10).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';

bool chatIsHttp(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.online,
    this.borderColor,
  });

  final String imageUrl;
  final double size;

  /// null = pas de pastille.
  final bool? online;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final s = size.w;
    final avatar = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Sans photo, le disque gris clair devenait une tache blanche sur le
        // fond sombre ; on garde exactement la valeur claire d'origine.
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A3A3A)
            : AppColors.lightGreyColor,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: chatIsHttp(imageUrl)
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: s,
              height: s,
              memCacheWidth: 160,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Icon(
                Icons.person_rounded,
                size: s * 0.55,
                color: AppColors.greyColor,
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: s * 0.55,
              color: AppColors.greyColor,
            ),
    );
    if (online == null) return avatar;
    final dot = s * 0.28;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: online! ? ChatRoleTheme.online : ChatRoleTheme.offline,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.card(context),
                  width: 2.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
