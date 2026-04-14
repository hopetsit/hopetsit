import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/post_model.dart';

/// Handles post-related API interactions.
class PostRepository {
  PostRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches media posts from the API.
  Future<List<PostModel>> getMediaPosts() async {
    final response = await _apiClient.get('/posts/media', requiresAuth: false);

    // Handle response with posts array and count
    if (response is Map<String, dynamic>) {
      if (response.containsKey('posts') && response['posts'] is List) {
        return (response['posts'] as List)
            .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // Fallback: handle direct list response
    if (response is List) {
      return response
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(
      'Unexpected get media posts response.',
      details: response,
    );
  }

  /// Fetches all posts from the API (including posts without media).
  Future<List<PostModel>> getAllPosts() async {
    final response = await _apiClient.get('/posts', requiresAuth: false);

    // Handle response with posts array and count
    if (response is Map<String, dynamic>) {
      if (response.containsKey('posts') && response['posts'] is List) {
        return (response['posts'] as List)
            .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    // Fallback: handle direct list response
    if (response is List) {
      return response
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException('Unexpected get all posts response.', details: response);
  }

  /// Adds a comment to a post.
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String body,
  }) async {
    final response = await _apiClient.post(
      '/posts/$postId/comments',
      body: {'body': body},
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected add comment response.', details: response);
  }

  /// Likes a post.
  Future<Map<String, dynamic>> likePost(String postId) async {
    final response = await _apiClient.post(
      '/posts/$postId/like',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected like post response.', details: response);
  }

  /// Dislikes (unlikes) a post.
  Future<Map<String, dynamic>> dislikePost(String postId) async {
    final response = await _apiClient.post(
      '/posts/$postId/dislike',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected dislike post response.', details: response);
  }

  /// Deletes a post by id.
  Future<Map<String, dynamic>> deletePost(String postId) async {
    final response = await _apiClient.delete(
      '/posts/$postId',
      requiresAuth: true,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException('Unexpected delete post response.', details: response);
  }
}
