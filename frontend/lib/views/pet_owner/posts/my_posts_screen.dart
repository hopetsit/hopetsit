import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/post_comment_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum MyPostsSortOrder { newestFirst, oldestFirst }

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  MyPostsSortOrder _sortOrder = MyPostsSortOrder.newestFirst;

  Future<void> _confirmAndDeletePost(
    BuildContext context,
    String postId,
    PostsController postsController,
  ) async {
    CustomConfirmationDialog.show(
      context: context,
      message: 'my_posts_delete_message'.tr,
      yesText: 'post_action_delete'.tr,
      cancelText: 'common_cancel'.tr,
      onYes: () async {
        try {
          final postRepository = Get.find<PostRepository>();
          await postRepository.deletePost(postId);
          await postsController.refreshPosts();
          CustomSnackbar.showSuccess(
            title: 'common_success'.tr,
            message: 'my_posts_delete_success'.tr,
          );
        } on ApiException catch (error) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: error.message,
          );
        } catch (error) {
          AppLogger.logError('MyPostsScreen: delete failed', error: error);
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: 'my_posts_delete_failed'.tr,
          );
        }
      },
    );
  }

  String _serviceTypesDisplay(List<String> types) {
    if (types.isEmpty) return '';
    return types.map((t) => t.replaceAll('_', ' ')).join(', ');
  }

  String? _postDateRangeLabel(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    if (s != null && e != null) {
      return '${s.day}/${s.month}/${s.year} - ${e.day}/${e.month}/${e.year}';
    }
    if (s != null) return '${s.day}/${s.month}/${s.year}';
    if (e != null) return '${e.day}/${e.month}/${e.year}';
    return null;
  }

  List<PostModel> _filterAndSortMyPosts(
    List<PostModel> media,
    List<PostModel> withoutMedia,
    String userId,
  ) {
    final seen = <String>{};
    final merged = <PostModel>[];

    for (final p in withoutMedia) {
      if (p.owner.id == userId && seen.add(p.id)) {
        merged.add(p);
      }
    }
    for (final p in media) {
      if (p.owner.id == userId && seen.add(p.id)) {
        merged.add(p);
      }
    }

    merged.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _sortOrder == MyPostsSortOrder.newestFirst ? -cmp : cmp;
    });

    return merged;
  }

  bool _postHasDisplayableMedia(PostModel post) {
    return post.images.any((img) => img.url.isNotEmpty) ||
        post.videos.isNotEmpty ||
        post.postType.toLowerCase() == 'media';
  }

  Widget _buildSortBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider(context).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sort_rounded, size: 20.sp, color: AppColors.grey700Color),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: 'my_posts_sort_label'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<MyPostsSortOrder>(
              value: _sortOrder,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryColor,
                size: 22.sp,
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
              items: [
                DropdownMenuItem(
                  value: MyPostsSortOrder.newestFirst,
                  child: InterText(
                    text: 'my_posts_sort_newest'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                DropdownMenuItem(
                  value: MyPostsSortOrder.oldestFirst,
                  child: InterText(
                    text: 'my_posts_sort_oldest'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sortOrder = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    PostModel post,
    PostsController postsController,
  ) {
    final hasMedia = _postHasDisplayableMedia(post);
    final imageUrls = post.images
        .map((img) => img.url)
        .where((url) => url.isNotEmpty)
        .toList();

    if (!hasMedia) {
      final petName = post.pets.isNotEmpty ? post.pets.first.petName : null;
      final rawCity = post.location?.city.trim();
      final locationLabel = (rawCity != null && rawCity.isNotEmpty)
          ? rawCity
          : null;
      final dateRangeLabel = _postDateRangeLabel(post);
      final serviceTypesLabel = _serviceTypesDisplay(post.serviceTypes);

      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: PetPostCard(
          userName: post.owner.name,
          userEmail: post.owner.email,
          userAvatar: post.owner.avatar.isNotEmpty ? post.owner.avatar : null,
          petImages: const <String>[],
          postBody: post.body,
          petName: petName,
          serviceTypes: serviceTypesLabel.isEmpty ? null : serviceTypesLabel,
          dateRange: dateRangeLabel,
          location: locationLabel,
          isNetworkImage: false,
          likeCount: post.likesCount,
          commentCount: post.commentsCount,
          isLiked: postsController.isPostLiked(post.id),
          onLike: () => postsController.toggleLike(post.id),
          onComment: () => PostCommentSheet.show(context, post),
          onDelete: () =>
              _confirmAndDeletePost(context, post.id, postsController),
          onViewPetDetails: null,
          onShare: () {
            () async {
              try {
                final shareText = post.body.isNotEmpty
                    ? post.body
                    : (post.pets.isNotEmpty &&
                              post.pets.first.petName.isNotEmpty
                          ? 'Meet ${post.pets.first.petName} — see this post on Hopetsit!'
                          : 'Check out my pet post on Hopetsit!');
                await SharePlus.instance.share(ShareParams(text: shareText));
              } catch (error) {
                AppLogger.logError('MyPostsScreen: share failed', error: error);
                CustomSnackbar.showError(
                  title: 'common_error'.tr,
                  message: 'share_failed'.tr,
                );
              }
            }();
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: PetPostCard(
        userName: post.owner.name,
        userEmail: post.owner.email,
        userAvatar: post.owner.avatar.isNotEmpty ? post.owner.avatar : null,
        petImages: imageUrls,
        postBody: post.body,
        petName: post.pets.isNotEmpty ? post.pets.first.petName : null,
        serviceTypes: _serviceTypesDisplay(post.serviceTypes).isEmpty
            ? null
            : _serviceTypesDisplay(post.serviceTypes),
        dateRange: _postDateRangeLabel(post),
        location: post.location?.city,
        isNetworkImage: imageUrls.isNotEmpty,
        likeCount: post.likesCount,
        commentCount: post.commentsCount,
        isLiked: postsController.isPostLiked(post.id),
        onLike: () => postsController.toggleLike(post.id),
        onComment: () => PostCommentSheet.show(context, post),
        onDelete: () =>
            _confirmAndDeletePost(context, post.id, postsController),
        onShare: () {
          () async {
            try {
              final shareText = post.body.isNotEmpty
                  ? post.body
                  : (post.pets.isNotEmpty && post.pets.first.petName.isNotEmpty
                        ? 'Meet ${post.pets.first.petName} — see this post on Hopetsit!'
                        : 'Check out my pet post on Hopetsit!');

              final filesToShare = <XFile>[];

              if (imageUrls.isNotEmpty) {
                final tmp = await getTemporaryDirectory();
                for (var i = 0; i < imageUrls.length; i++) {
                  final imageUrl = imageUrls[i];
                  if (imageUrl.startsWith('http')) {
                    final uri = Uri.parse(imageUrl);
                    final resp = await http.get(uri);
                    if (resp.statusCode == 200) {
                      final bytes = resp.bodyBytes;
                      final file = File('${tmp.path}/share_${post.id}_$i.jpg');
                      await file.writeAsBytes(bytes);
                      filesToShare.add(XFile(file.path));
                    }
                  } else {
                    try {
                      final data = await rootBundle.load(imageUrl);
                      final bytes = data.buffer.asUint8List();
                      final file = File('${tmp.path}/share_${post.id}_$i.png');
                      await file.writeAsBytes(bytes);
                      filesToShare.add(XFile(file.path));
                    } catch (_) {}
                  }
                }
              }

              if (filesToShare.isNotEmpty) {
                await SharePlus.instance.share(ShareParams(files: filesToShare, text: shareText));
              } else {
                await SharePlus.instance.share(ShareParams(text: shareText));
              }
            } catch (error) {
              AppLogger.logError('MyPostsScreen: share failed', error: error);
              CustomSnackbar.showError(
                title: 'common_error'.tr,
                message: 'share_failed'.tr,
              );
            }
          }();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postsController = Get.put(PostsController());
    final storage = Get.find<GetStorage>();
    final userProfile =
        storage.read(StorageKeys.userProfile) as Map<String, dynamic>?;
    final userId = userProfile?['id'] as String?;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        title: InterText(
          text: 'my_posts_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
      ),
      body: SafeArea(
        child: Obx(() {
          final isLoading = postsController.isLoading.value;

          final sortedMine = userId == null
              ? <PostModel>[]
              : _filterAndSortMyPosts(
                  postsController.posts,
                  postsController.postsWithoutMedia,
                  userId,
                );

          if (isLoading && sortedMine.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (sortedMine.isEmpty) {
            return Center(
              child: InterText(
                text: 'my_posts_no_posts'.tr,
                fontSize: 14.sp,
                color: AppColors.textSecondary(context),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSortBar(context),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primaryColor,
                  onRefresh: () => postsController.refreshPosts(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        ...sortedMine.map(
                          (post) =>
                              _buildPostCard(context, post, postsController),
                        ),
                        SizedBox(height: 50.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
