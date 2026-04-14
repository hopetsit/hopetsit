import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/post_comment_sheet.dart';

/// Shows a single post as the same [PetPostCard] used on the home feed (e.g. from a like notification).
class NotificationPostViewScreen extends StatefulWidget {
  const NotificationPostViewScreen({
    super.key,
    required this.post,
    this.openCommentsOnOpen = false,
  });

  final PostModel post;
  final bool openCommentsOnOpen;

  @override
  State<NotificationPostViewScreen> createState() =>
      _NotificationPostViewScreenState();
}

class _NotificationPostViewScreenState
    extends State<NotificationPostViewScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.openCommentsOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          PostCommentSheet.show(context, widget.post);
        }
      });
    }
  }

  static String? _postDateRangeLabel(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    if (s != null && e != null) {
      return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year}';
    }
    if (s != null) return '${s.day}/${s.month}/${s.year}';
    if (e != null) return '${e.day}/${e.month}/${e.year}';
    return null;
  }

  static String _serviceTypesDisplay(List<String> types) {
    if (types.isEmpty) return '';
    return types.map((t) => t.replaceAll('_', ' ')).join(', ');
  }

  PostModel _livePost(PostsController c) {
    for (final p in c.posts) {
      if (p.id == widget.post.id) return p;
    }
    for (final p in c.postsWithoutMedia) {
      if (p.id == widget.post.id) return p;
    }
    return widget.post;
  }

  @override
  Widget build(BuildContext context) {
    final postsController = Get.isRegistered<PostsController>()
        ? Get.find<PostsController>()
        : Get.put(PostsController());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.whiteColor,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: InterText(
          text: 'notifications_post_view_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: Obx(() {
            postsController.posts;
            postsController.postsWithoutMedia;
            final post = _livePost(postsController);
            final imageUrls = post.images
                .map((img) => img.url)
                .where((url) => url.isNotEmpty)
                .toList();
            final petName = post.pets.isNotEmpty
                ? post.pets.first.petName
                : null;
            final rawCity = post.location?.city.trim();
            final locationLabel = (rawCity != null && rawCity.isNotEmpty)
                ? rawCity
                : null;
            final dateRangeLabel = _postDateRangeLabel(post);
            final serviceTypesLabel = _serviceTypesDisplay(post.serviceTypes);

            return PetPostCard(
              userName: post.owner.name,
              userEmail: '',
              userAvatar: post.owner.avatar.isNotEmpty
                  ? post.owner.avatar
                  : null,
              petImages: imageUrls,
              postBody: post.body,
              petName: petName,
              serviceTypes: serviceTypesLabel.isEmpty
                  ? null
                  : serviceTypesLabel,
              dateRange: dateRangeLabel,
              location: locationLabel,
              isNetworkImage: imageUrls.isNotEmpty,
              likeCount: post.likesCount,
              commentCount: post.commentsCount,
              isLiked: postsController.isPostLiked(post.id),
              onLike: () => postsController.toggleLike(post.id),
              onComment: () => PostCommentSheet.show(context, post),
            );
          }),
        ),
      ),
    );
  }
}
