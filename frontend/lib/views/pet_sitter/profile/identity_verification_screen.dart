import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 5 step 7 — Sitter identity verification screen.
/// Pick a photo of ID document → submit → show status.
class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();
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
        '/sitters/me/identity-verification',
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

  Future<void> _pickAndUpload() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final token = GetStorage().read<String>(StorageKeys.authToken) ?? '';
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/sitters/identity-verification'),
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
          message: 'Identity document submitted. Awaiting review.',
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
        return _banner(Colors.green, 'Identity verified ✓');
      case 'pending':
        return _banner(Colors.orange, 'Under review — please wait.');
      case 'rejected':
        return _banner(
          Colors.red,
          'Rejected. Reason: ${_rejectionReason.isEmpty ? "—" : _rejectionReason}',
        );
      default:
        return _banner(Colors.grey, 'Not submitted yet.');
    }
  }

  Widget _banner(Color bg, String label) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.15),
          border: Border.all(color: bg),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(label, style: TextStyle(color: bg, fontWeight: FontWeight.w600)),
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
        title: Text('Identity verification', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBanner(),
            SizedBox(height: 16.h),
            Text(
              'Upload a photo of your ID document (passport or ID card). Only admins and you will be able to see it.',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: Text(_uploading ? 'Uploading...' : 'Upload ID document'),
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
