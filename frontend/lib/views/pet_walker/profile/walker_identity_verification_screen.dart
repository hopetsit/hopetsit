import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:image_picker/image_picker.dart';

/// Walker identity verification screen — session v3.2.
///
/// Mirror of the sitter screen but hitting `/walkers/identity-verification`
/// and `/walkers/me/identity-verification`. Uses the same simple-upload
/// flow today; migration to Stripe Identity (via POST
/// /identity-verification/session) lands once the Stripe key is provisioned
/// — the backend route already exists and will be preferred when active.
class WalkerIdentityVerificationScreen extends StatefulWidget {
  const WalkerIdentityVerificationScreen({super.key});

  @override
  State<WalkerIdentityVerificationScreen> createState() =>
      _WalkerIdentityVerificationScreenState();
}

class _WalkerIdentityVerificationScreenState
    extends State<WalkerIdentityVerificationScreen> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
  final ImagePicker _picker = ImagePicker();

  String _status = 'none';
  String _rejectionReason = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final r = await _api.get(
        '/walkers/me/identity-verification',
        requiresAuth: true,
      );
      if (r is Map) {
        setState(() {
          _status = (r['status'] as String?) ?? 'none';
          _rejectionReason = (r['rejectionReason'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  /// Try the modern flow (Stripe Identity session) first. If the backend
  /// replies 503 IDENTITY_NOT_CONFIGURED, fall back to the simple upload.
  Future<void> _startVerification() async {
    setState(() => _uploading = true);
    try {
      final data = await _api.post(
        '/identity-verification/session',
        requiresAuth: true,
        body: const {},
      );
      if (data is Map && data['clientSecret'] is String) {
        // TODO wire Stripe Identity native SDK when the package is added to
        // pubspec.yaml. For now open the hosted URL as a browser fallback
        // so real-world testing is possible before the SDK lands.
        final url = data['url']?.toString() ?? '';
        if (!mounted) return;
        CustomSnackbar.showSuccess(
          title: 'Vérification démarrée',
          message: url.isNotEmpty
              ? 'Suis le lien Stripe pour terminer.'
              : 'Session Identity créée, ouvre le SDK.',
        );
        await _refreshStatus();
        return;
      }
    } catch (e) {
      // Fall back to the simple upload path if Stripe Identity is not
      // configured (503 IDENTITY_NOT_CONFIGURED) or any other failure.
      await _pickAndUpload();
      return;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final token = GetStorage().read<String>(StorageKeys.authToken) ?? '';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/walkers/identity-verification'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('document', picked.path),
      );
      final streamed = await request.send();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        await _refreshStatus();
        CustomSnackbar.showSuccess(
          title: 'common_success',
          message: 'Document envoyé. En attente de vérification.',
        );
      } else {
        CustomSnackbar.showError(
          title: 'common_error',
          message: 'Upload failed (${streamed.statusCode}).',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _statusBanner() {
    switch (_status) {
      case 'verified':
        return _banner(Colors.green, 'Identité vérifiée ✓');
      case 'pending':
        return _banner(Colors.orange, 'En cours de vérification…');
      case 'rejected':
        return _banner(
          Colors.red,
          'Refusé · ${_rejectionReason.isEmpty ? "—" : _rejectionReason}',
        );
      default:
        return _banner(Colors.grey, 'Aucun document envoyé.');
    }
  }

  Widget _banner(Color bg, String label) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.15),
          border: Border.all(color: bg),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(color: bg, fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Vérification d\'identité',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBanner(),
            SizedBox(height: 16.h),
            Text(
              'Envoie une photo de ton document d\'identité (passeport ou carte). '
              'Seul l\'admin et toi pouvez le consulter. '
              'Cette vérification est nécessaire pour proposer tes services de promenade.',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _startVerification,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_uploading ? 'Traitement…' : 'Démarrer la vérification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
