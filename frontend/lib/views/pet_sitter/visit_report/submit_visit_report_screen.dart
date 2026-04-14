import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 6 step 3 — sitter submits a visit report with photos.
class SubmitVisitReportScreen extends StatefulWidget {
  final String bookingId;
  const SubmitVisitReportScreen({super.key, required this.bookingId});

  @override
  State<SubmitVisitReportScreen> createState() =>
      _SubmitVisitReportScreenState();
}

class _SubmitVisitReportScreenState extends State<SubmitVisitReportScreen> {
  final _notesController = TextEditingController();
  final _activitiesController = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _photos = [];
  String _mood = 'calm';
  bool _busy = false;

  Future<void> _pick() async {
    if (_photos.length >= 10) return;
    final picked = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked.isNotEmpty) {
      setState(() {
        for (final x in picked) {
          if (_photos.length < 10) _photos.add(File(x.path));
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final token = GetStorage().read<String>(StorageKeys.authToken) ?? '';
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/bookings/${widget.bookingId}/visit-report'),
      );
      req.headers['Authorization'] = 'Bearer $token';
      req.fields['notes'] = _notesController.text.trim();
      req.fields['mood'] = _mood;
      req.fields['activities'] = _activitiesController.text.trim();
      for (final f in _photos) {
        req.files.add(await http.MultipartFile.fromPath('photos', f.path));
      }
      final resp = await req.send();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        CustomSnackbar.showSuccess(
          title: 'common_success',
          message: 'Visit report submitted.',
        );
        if (mounted) Get.back();
      } else {
        CustomSnackbar.showError(
          title: 'common_error',
          message: 'Failed (${resp.statusCode})',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mood,
            decoration: const InputDecoration(labelText: 'Mood'),
            items: const [
              DropdownMenuItem(value: 'happy', child: Text('😊 Happy')),
              DropdownMenuItem(value: 'calm', child: Text('😌 Calm')),
              DropdownMenuItem(value: 'anxious', child: Text('😟 Anxious')),
            ],
            onChanged: (v) => setState(() => _mood = v ?? 'calm'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _activitiesController,
            decoration: const InputDecoration(
              labelText: 'Activities (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(f, width: 72, height: 72, fit: BoxFit.cover),
                ),
              InkWell(
                onTap: _pick,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_a_photo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending...' : 'Submit report'),
          ),
        ],
      ),
    );
  }
}
