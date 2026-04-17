import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/report_dialog.dart';
import 'package:intl/intl.dart';

class PostCommentSheet extends StatefulWidget {
  final PostModel post;

  const PostCommentSheet({super.key, required this.post});

  static void show(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostCommentSheet(post: post),
    );
  }

  @override
  State<PostCommentSheet> createState() => _PostCommentSheetState();
}

class _PostCommentSheetState extends State<PostCommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final RxBool _isSubmitting = false.obs;
  final RxString _commentText = ''.obs;
  final RxList<PostComment> _comments = <PostComment>[].obs;
  late PostModel _currentPost;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _comments.assignAll(widget.post.comments);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    _isSubmitting.value = true;

    try {
      final postRepository = Get.find<PostRepository>();
      await postRepository.addComment(
        postId: _currentPost.id,
        body: commentText,
      );

      // Clear the input
      _commentController.clear();
      _commentText.value = '';

      // Refresh posts (GET) so feed and comment data match server
      final postsController = Get.find<PostsController>();
      await postsController.refreshPosts();

      // Post may live in media feed or non-media list — check both
      final updatedPost =
          postsController.posts.firstWhereOrNull(
            (p) => p.id == _currentPost.id,
          ) ??
          postsController.postsWithoutMedia.firstWhereOrNull(
            (p) => p.id == _currentPost.id,
          );
      if (updatedPost != null) {
        _currentPost = updatedPost;
        _comments.assignAll(updatedPost.comments);
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'post_comment_added_success'.tr,
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'post_comment_add_failed'.tr,
      );
    } finally {
      _isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.greyText.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  InterText(
                    text: 'post_comments_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackColor,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 24.sp),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(height: 1.h, color: AppColors.greyText.withOpacity(0.2)),

            // Comments list
            Expanded(
              child: Obx(
                () => _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 48.sp,
                              color: AppColors.greyText.withOpacity(0.5),
                            ),
                            SizedBox(height: 16.h),
                            InterText(
                              text: 'post_comments_empty_title'.tr,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.greyText,
                            ),
                            SizedBox(height: 8.h),
                            InterText(
                              text: 'post_comments_empty_subtitle'.tr,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.greyText.withOpacity(0.7),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
              ),
            ),

            // Comment input section
            Divider(height: 1.h, color: AppColors.greyText.withOpacity(0.2)),
            Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 8.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 25.h,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      onChanged: (value) {
                        _commentText.value = value;
                      },
                      decoration: InputDecoration(
                        hintText: 'post_comments_hint'.tr,
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.greyText,
                        ),
                        filled: true,
                        fillColor: AppColors.lightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.blackColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Obx(
                    () => _isSubmitting.value
                        ? Padding(
                            padding: EdgeInsets.all(8.w),
                            child: SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryColor,
                                ),
                              ),
                            ),
                          )
                        : Obx(
                            () => IconButton(
                              icon: Icon(
                                Icons.send,
                                color: _commentText.value.trim().isNotEmpty
                                    ? AppColors.primaryColor
                                    : AppColors.greyText.withOpacity(0.5),
                                size: 24.sp,
                              ),
                              onPressed: _commentText.value.trim().isNotEmpty
                                  ? _submitComment
                                  : null,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(PostComment comment) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20.r,
            backgroundColor: AppColors.primaryColor,
            child: CircleAvatar(
              radius: 18.r,
              backgroundColor: AppColors.lightGrey,
              backgroundImage: comment.authorAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(comment.authorAvatar)
                  : null,
              child: comment.authorAvatar.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 18.sp,
                      color: AppColors.primaryColor,
                    )
                  : null,
            ),
          ),
          SizedBox(width: 12.w),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment header
                Row(
                  children: [
                    InterText(
                      text: comment.authorName,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackColor,
                    ),
                    if (comment.userRole.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: InterText(
                          text: comment.userRole,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),

                // Comment body
                InterText(
                  text: comment.body,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackColor,
                ),
                SizedBox(height: 4.h),

                // Comment time + report button
                Row(
                  children: [
                    InterText(
                      text: formatDateTime(comment.createdAt),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.greyText,
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        ReportDialog.show(
                          context: context,
                          targetType: 'comment',
                          targetId: comment.id,
                          snapshot: comment.body,
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 12.sp,
                              color: AppColors.greyText,
                            ),
                            SizedBox(width: 3.w),
                            InterText(
                              text: 'report_short_label'.tr,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.greyText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatDateTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 7) {
    return DateFormat('MMM d, y').format(dateTime);
  } else if (difference.inDays > 0) {
    return 'time_days_ago'.trParams({'count': difference.inDays.toString()});
  } else if (difference.inHours > 0) {
    return 'time_hours_ago'.trParams({'count': difference.inHours.toString()});
  } else if (difference.inMinutes > 0) {
    return 'time_minutes_ago'.trParams({
      'count': difference.inMinutes.toString(),
    });
  } else {
    return 'time_just_now'.tr;
  }
}
