// v565 — point 13 : enregistreur vocal (package `record`, AAC dans un .m4a).
//   - appui long sur le micro : enregistre, glisser vers la gauche = annuler,
//     relâcher = envoyer ;
//   - simple tap sur le micro : enregistrement « verrouillé » avec boutons
//     Annuler / Envoyer (accessibilité).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// État d'enregistrement partagé entre le bouton micro et la barre.
class VoiceRecordController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;

  bool isRecording = false;

  /// true = démarré par un tap (boutons visibles), false = appui maintenu.
  bool locked = false;

  /// Le doigt a glissé assez loin : l'annulation est armée.
  bool cancelArmed = false;
  int elapsedSeconds = 0;
  double amplitude = 0; // 0..1

  static const int minSeconds = 1;
  static const int maxSeconds = 120;

  Future<bool> start({required bool locked}) async {
    if (isRecording) return true;
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        CustomSnackbar.showWarning(
          title: 'cs_action_voice'.tr,
          message: 'cs_rec_permission'.tr,
        );
        return false;
      }
      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _path!,
      );
      isRecording = true;
      this.locked = locked;
      cancelArmed = false;
      elapsedSeconds = 0;
      amplitude = 0;
      _startedAt = DateTime.now();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        if (!isRecording) return;
        elapsedSeconds =
            DateTime.now().difference(_startedAt!).inSeconds.clamp(0, 9999);
        try {
          final a = await _recorder.getAmplitude();
          // dBFS ≈ -60 (silence) → 0 (max)
          amplitude = ((a.current + 60) / 60).clamp(0.0, 1.0);
        } catch (_) {/* amplitude indisponible → barre statique */}
        notifyListeners();
        if (elapsedSeconds >= maxSeconds) {
          await stop(send: true);
        }
      });
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.logError('voice record start failed', error: e);
      isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// Callback déclenché quand un fichier valide est prêt à partir.
  Future<void> Function(File file, int seconds)? onSend;

  void setCancelArmed(bool v) {
    if (cancelArmed == v) return;
    cancelArmed = v;
    notifyListeners();
  }

  Future<void> stop({required bool send}) async {
    if (!isRecording) return;
    _ticker?.cancel();
    _ticker = null;
    isRecording = false;
    final seconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMilliseconds / 1000.0;
    String? out;
    try {
      out = await _recorder.stop();
    } catch (e) {
      AppLogger.logError('voice record stop failed', error: e);
    }
    notifyListeners();
    final path = out ?? _path;
    if (!send || cancelArmed) {
      _discard(path);
      return;
    }
    if (seconds < minSeconds || path == null || !File(path).existsSync()) {
      _discard(path);
      CustomSnackbar.showInfo(
        title: 'cs_action_voice'.tr,
        message: 'cs_rec_too_short'.tr,
      );
      return;
    }
    final cb = onSend;
    if (cb != null) await cb(File(path), seconds.round().clamp(1, maxSeconds));
  }

  Future<void> cancel() async {
    cancelArmed = true;
    await stop(send: false);
    cancelArmed = false;
    notifyListeners();
  }

  void _discard(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {/* best effort */}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (isRecording) {
      _recorder.stop().then((p) => _discard(p)).catchError((_) => null);
    }
    _recorder.dispose();
    super.dispose();
  }
}

/// Barre affichée à la place du champ de saisie pendant l'enregistrement.
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({
    super.key,
    required this.controller,
    required this.theme,
  });

  final VoiceRecordController controller;
  final ChatRoleTheme theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final armed = controller.cancelArmed;
        return Container(
          height: 48.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: armed
                ? AppColors.errorColor.withValues(alpha: 0.10)
                : AppColors.inputFill(context),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            children: [
              _PulsingDot(color: AppColors.errorColor),
              SizedBox(width: 8.w),
              Text(
                chatDuration(controller.elapsedSeconds),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: controller.locked
                    ? _Bars(
                        level: controller.amplitude,
                        color: theme.accentOn(context))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left_rounded,
                              size: 18.sp,
                              color: armed
                                  ? AppColors.errorColor
                                  : AppColors.textSecondary(context)),
                          Flexible(
                            child: InterText(
                              text: armed
                                  ? 'cs_rec_release_cancel'.tr
                                  : 'cs_rec_slide_cancel'.tr,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: armed
                                  ? AppColors.errorColor
                                  : AppColors.textSecondary(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              if (controller.locked)
                IconButton(
                  tooltip: 'common_cancel'.tr,
                  onPressed: controller.cancel,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.errorColor, size: 22.sp),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_c),
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Petites barres qui bougent avec l'amplitude.
class _Bars extends StatelessWidget {
  const _Bars({required this.level, required this.color});
  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const n = 14;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(n, (i) {
        final phase = ((i * 7) % n) / n;
        final h = 4 + 16 * (level * (0.4 + 0.6 * phase));
        return Container(
          width: 3.w,
          height: h.h,
          margin: EdgeInsets.symmetric(horizontal: 1.5.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
