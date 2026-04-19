import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class PostsController extends GetxController {
  PostsController({PostRepository? postRepository, GetStorage? storage})
    : _postRepository = postRepository ?? Get.find<PostRepository>(),
      _storage = storage ?? Get.find<GetStorage>();

  final PostRepository _postRepository;
  final GetStorage _storage;

  final RxBool isLoading = false.obs;
  final RxList<PostModel> posts = <PostModel>[].obs;
  final RxList<PostModel> postsWithoutMedia = <PostModel>[].obs;

  /// Posts that have reservation request data (startDate, endDate, location, serviceTypes, petId).
  final RxList<PostModel> reservationRequests = <PostModel>[].obs;
  final RxString errorMessage = ''.obs;

  String? get _currentUserId {
    final userProfile = _storage.read<Map<String, dynamic>>(
      StorageKeys.userProfile,
    );
    return userProfile?['id'] as String?;
  }

  @override
  void onInit() {
    super.onInit();
    loadMediaPosts();
    loadPostsWithoutMedia();
    // Session v15-6 — the authenticated endpoint that filters by role.
    // Needed so Sitter/Walker see owner reservation requests in their feed.
    loadReservationRequests();
  }

  /// Session v15-6 — P0 fix from recap v15 that was pending.
  /// Pulls `/posts/requests` with auth so the backend filters by the
  /// caller's role (walker → dog_walking, sitter → excludes dog_walking and
  /// respects service-location preferences). Owners still get their own
  /// full view via /posts (kept as-is to avoid breaking "Mes publications").
  Future<void> loadReservationRequests() async {
    try {
      final requests = await _postRepository.getRequestPosts();
      reservationRequests.assignAll(requests);
      debugPrint(
        '[FEED DEBUG] loadReservationRequests → /posts/requests renvoie ${requests.length} posts filtrés par rôle',
      );
    } catch (e) {
      debugPrint('[FEED DEBUG] loadReservationRequests EXCEPTION: $e');
      // Silently fail — sitter/walker feed will just stay on the last
      // cached snapshot rather than flashing an error banner.
    }
  }

  Future<void> loadMediaPosts() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _postRepository.getMediaPosts();
      posts.assignAll(response);
      // --- DEBUG TEMPORAIRE (Étape 1 diagnostic feed) ---
      debugPrint('[FEED DEBUG] loadMediaPosts → ${response.length} posts reçus de /posts/media');
      for (final p in response) {
        debugPrint('  • id=${p.id} body="${p.body}" '
            'serviceTypes=${p.serviceTypes} '
            'isReservationRequest=${p.isReservationRequest}');
      }
      // ---------------------------------------------------
    } catch (e) {
      errorMessage.value = e.toString();
      debugPrint('[FEED DEBUG] loadMediaPosts EXCEPTION: $e');
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'posts_load_failed'.tr,
      );
      posts.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPostsWithoutMedia() async {
    try {
      final allPosts = await _postRepository.getAllPosts();
      // --- DEBUG TEMPORAIRE (Étape 1 diagnostic feed) ---
      debugPrint('[FEED DEBUG] loadPostsWithoutMedia → /posts renvoie ${allPosts.length} posts au total');
      for (final p in allPosts) {
        debugPrint('  • id=${p.id} postType="${p.postType}" '
            'serviceTypes=${p.serviceTypes} '
            'startDate=${p.startDate} '
            'petId=${p.petId} '
            'location.city=${p.location?.city} '
            'isReservationRequest=${p.isReservationRequest}');
      }
      // ---------------------------------------------------

      // Filter posts without media (no images, no videos, and not postType "media")
      final withoutMedia = allPosts.where((post) {
        final hasImages = post.images.isNotEmpty;
        final hasVideos = post.videos.isNotEmpty;
        final isMediaType = post.postType.toLowerCase() == 'media';
        return !hasImages && !hasVideos && !isMediaType;
      }).toList();
      postsWithoutMedia.assignAll(withoutMedia);
      // Reservation requests: any post with request data (dates, location, service, pet)
      final requests = allPosts.where((p) => p.isReservationRequest).toList();
      reservationRequests.assignAll(requests);

      // --- DEBUG TEMPORAIRE (Étape 1 diagnostic feed) ---
      debugPrint('[FEED DEBUG] ➜ postsWithoutMedia = ${withoutMedia.length}');
      debugPrint('[FEED DEBUG] ➜ reservationRequests = ${requests.length}');
      // Simule le filtre Walker et Sitter pour valider ce qui passerait
      final walkerFeed = requests.where((p) => p.serviceTypes
              .map((t) => t.toLowerCase())
              .contains('dog_walking'))
          .toList();
      const sitterServices = <String>{'pet_sitting', 'house_sitting', 'day_care'};
      final sitterFeed = requests.where((p) {
        final types = p.serviceTypes.map((t) => t.toLowerCase()).toSet();
        return types.any(sitterServices.contains);
      }).toList();
      debugPrint('[FEED DEBUG] ➜ après filtre Walker (dog_walking) : ${walkerFeed.length}');
      debugPrint('[FEED DEBUG] ➜ après filtre Sitter (pet_sitting|day_care|house_sitting) : ${sitterFeed.length}');
      // ---------------------------------------------------
    } catch (e) {
      debugPrint('[FEED DEBUG] loadPostsWithoutMedia EXCEPTION: $e');
      // Silently fail for posts without media, don't show error
      postsWithoutMedia.clear();
      reservationRequests.clear();
    }
  }

  Future<void> refreshPosts() async {
    await Future.wait([
      loadMediaPosts(),
      loadPostsWithoutMedia(),
      loadReservationRequests(),
    ]);
  }

  /// Toggles like status for a post with optimistic update.
  Future<void> toggleLike(String postId) async {
    final userId = _currentUserId;
    if (userId == null) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'posts_like_login_required'.tr,
      );
      return;
    }

    final postIndex = posts.indexWhere((p) => p.id == postId);
    final withoutMediaIndex = postsWithoutMedia.indexWhere((p) => p.id == postId);
    if (postIndex == -1 && withoutMediaIndex == -1) return;

    final post = postIndex != -1
        ? posts[postIndex]
        : postsWithoutMedia[withoutMediaIndex];
    final isCurrentlyLiked = post.isLikedByUser(userId);

    // Optimistic update: immediately update UI
    final newLikesCount = isCurrentlyLiked
        ? (post.likesCount - 1).clamp(0, double.infinity).toInt()
        : post.likesCount + 1;

    final newLikes = isCurrentlyLiked
        ? post.likes.where((like) => like.userId != userId).toList()
        : [
            ...post.likes,
            PostLike(id: '', userId: userId, createdAt: DateTime.now()),
          ];

    final updatedPost = post.copyWith(
      likes: newLikes,
      likesCount: newLikesCount,
    );

    if (postIndex != -1) {
      posts[postIndex] = updatedPost;
    } else {
      postsWithoutMedia[withoutMediaIndex] = updatedPost;
    }

    // Call API in background
    try {
      if (isCurrentlyLiked) {
        await _postRepository.dislikePost(postId);
      } else {
        await _postRepository.likePost(postId);
      }
      // Optionally refresh to get server state
      // await refreshPosts();
    } catch (e) {
      // Revert optimistic update on error
      if (postIndex != -1) {
        posts[postIndex] = post;
      } else {
        postsWithoutMedia[withoutMediaIndex] = post;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: isCurrentlyLiked
            ? 'posts_unlike_failed'.tr
            : 'posts_like_failed'.tr,
      );
    }
  }

  /// Checks if a post is liked by the current user.
  bool isPostLiked(String postId) {
    final userId = _currentUserId;
    if (userId == null) return false;

    final post =
        posts.firstWhereOrNull((p) => p.id == postId) ??
        postsWithoutMedia.firstWhereOrNull((p) => p.id == postId);
    return post?.isLikedByUser(userId) ?? false;
  }
}
