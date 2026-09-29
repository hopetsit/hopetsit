// v565 — point 13 : bulle de message vocal (lecture / pause, forme d'onde,
// durée) avec `audioplayers`.
// v599 (ZOE, 29/09/2026) — Daniel : « j'entends rien » + « ondes sonores ».
//   - LECTURE ROBUSTE : avant chaque lecture on impose le contexte audio
//     (iOS : catégorie `playback` → le vocal sort sur le haut-parleur et
//     IGNORE l'interrupteur silencieux ; après un enregistrement, le paquet
//     `record` laissait la session en `playAndRecord` ; Android : usage
//     `media` + contenu `speech`, focus transitoire) et le volume à 1.
//   - FORME D'ONDE : la vraie onde captée à l'enregistrement
//     (`attachment.waveform`) rendue en barres, remplies au fil de la lecture ;
//     un vocal antérieur (sans onde) reçoit un motif stable dérivé de son URL.
//     Même rendu iPhone / Android, couleurs de la bulle, aucun gris.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';

/// Nombre de barres affichées dans une bulle.
const int kVoiceBars = 40;

/// Contexte audio imposé avant chaque lecture d'un vocal.
final AudioContext kVoiceAudioContext = AudioContext(
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: const {},
  ),
  android: const AudioContextAndroid(
    isSpeakerphoneOn: false,
    stayAwake: false,
    contentType: AndroidContentType.speech,
    usageType: AndroidUsageType.media,
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,
  ),
);

/// Ramène une liste d'amplitudes (0..1) à exactement [n] barres, par moyenne
/// de tranches (ou interpolation si la source est plus courte). Chaque barre
/// est bornée à [0.08, 1] pour rester visible.
List<double> resampleWaveform(List<double> src, int n) {
  if (n <= 0) return const [];
  if (src.isEmpty) return List<double>.filled(n, 0.08);
  final out = List<double>.filled(n, 0.0);
  if (src.length >= n) {
    for (var i = 0; i < n; i++) {
      final a = (i * src.length / n).floor();
      var b = ((i + 1) * src.length / n).floor();
      if (b <= a) b = a + 1;
      var sum = 0.0;
      var k = 0;
      for (var j = a; j < b && j < src.length; j++) {
        sum += src[j];
        k++;
      }
      out[i] = k == 0 ? 0 : sum / k;
    }
  } else {
    for (var i = 0; i < n; i++) {
      final pos = i * (src.length - 1) / (n - 1 == 0 ? 1 : n - 1);
      final lo = pos.floor();
      final hi = (lo + 1).clamp(0, src.length - 1);
      final t = pos - lo;
      out[i] = src[lo] * (1 - t) + src[hi] * t;
    }
  }
  var max = 0.0;
  for (final v in out) {
    if (v > max) max = v;
  }
  final scale = max > 0.05 ? 1.0 / max : 1.0;
  for (var i = 0; i < n; i++) {
    out[i] = (out[i] * scale).clamp(0.08, 1.0);
  }
  return out;
}

/// Motif stable (déterministe) pour un vocal SANS onde enregistrée : dérivé
/// de son URL, jamais une ligne droite.
List<double> fallbackWaveform(String seed, int n) {
  var h = 2166136261;
  for (final c in seed.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xffffffff;
  }
  final out = List<double>.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    final r = (h >> 8) / 0x7fffff;
    // enveloppe douce : plus fort au milieu, comme une phrase parlée
    final env = 0.55 + 0.45 * (1 - ((i - n / 2).abs() / (n / 2)));
    out[i] = (0.25 + 0.75 * r * env).clamp(0.12, 1.0);
  }
  return out;
}

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.attachment,
    required this.mine,
    required this.theme,
    this.pending = false,
  });

  final ChatAttachment attachment;
  final bool mine;
  final ChatRoleTheme theme;
  final bool pending;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = false;
  bool _error = false;
  late List<double> _bars = _computeBars();

  List<double> _computeBars() {
    final w = widget.attachment.waveform;
    if (w != null && w.isNotEmpty) return resampleWaveform(w, kVoiceBars);
    return fallbackWaveform(
      widget.attachment.localPath ?? widget.attachment.url,
      kVoiceBars,
    );
  }

  @override
  void didUpdateWidget(covariant VoiceMessagePlayer old) {
    super.didUpdateWidget(old);
    if (old.attachment.url != widget.attachment.url ||
        old.attachment.waveform != widget.attachment.waveform) {
      _bars = _computeBars();
    }
  }

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.stop);
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _state = s;
        if (s == PlayerState.playing) _loading = false;
      });
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _state = PlayerState.completed;
        _position = Duration.zero;
      });
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.pending) return;
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
        return;
      }
      if (_state == PlayerState.paused) {
        await _player.resume();
        return;
      }
      setState(() {
        _loading = true;
        _error = false;
      });
      // v599 — haut-parleur + interrupteur silencieux ignoré (iOS), focus
      // audio (Android), volume plein : « j'entends rien » ne doit plus arriver.
      try {
        await _player.setAudioContext(kVoiceAudioContext);
      } catch (e) {
        AppLogger.logError('voice audio context failed', error: e);
      }
      try {
        await _player.setVolume(1.0);
      } catch (_) {/* best effort */}
      final a = widget.attachment;
      final Source src = a.localPath != null
          ? DeviceFileSource(a.localPath!)
          : UrlSource(a.url);
      await _player.play(src);
    } catch (e) {
      AppLogger.logError('voice play failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  void _seekToFraction(double f) {
    final total = _duration ??
        Duration(seconds: (widget.attachment.duration ?? 0).round());
    if (total.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (total.inMilliseconds * f.clamp(0.0, 1.0)).round(),
    );
    _player.seek(target);
    setState(() => _position = target);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    // Bulle envoyée : blanc sur la couleur du rôle. Bulle reçue : accent du
    // rôle (éclairci en mode sombre). Jamais de gris.
    final fg = widget.mine ? Colors.white : t.accentOn(context);
    final total = _duration ??
        Duration(seconds: (widget.attachment.duration ?? 0).round());
    final playing = _state == PlayerState.playing;
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final shown = playing || _state == PlayerState.paused
        ? total - _position
        : total;

    return SizedBox(
      width: 220.w,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: widget.mine
                    ? Colors.white.withValues(alpha: 0.22)
                    : t.softTintStrong(context),
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? Padding(
                      padding: EdgeInsets.all(10.w),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  : Icon(
                      _error
                          ? Icons.error_outline_rounded
                          : playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                      color: fg,
                      size: 24.sp,
                    ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30.h,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: total.inMilliseconds > 0
                        ? (d) => _seekToFraction(
                              d.localPosition.dx / (220.w - 48.w - 10.w))
                        : null,
                    onHorizontalDragUpdate: total.inMilliseconds > 0
                        ? (d) => _seekToFraction(
                              d.localPosition.dx / (220.w - 48.w - 10.w))
                        : null,
                    child: VoiceWaveform(
                      bars: _bars,
                      progress: progress,
                      color: fg,
                      // barres non lues : même teinte, adoucie (pas de gris)
                      dimColor: fg.withValues(alpha: 0.38),
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_rounded, size: 12.sp, color: fg),
                    SizedBox(width: 4.w),
                    Text(
                      chatDuration(shown.inSeconds),
                      style: TextStyle(
                        color: fg,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
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

/// Forme d'onde en barres arrondies ; les barres déjà lues sont pleines.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.bars,
    required this.progress,
    required this.color,
    required this.dimColor,
    this.barWidth = 3,
    this.gap = 1.6,
  });

  final List<double> bars;
  final double progress;
  final Color color;
  final Color dimColor;
  final double barWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(
        bars: bars,
        progress: progress,
        color: color,
        dimColor: dimColor,
        barWidth: barWidth,
        gap: gap,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.color,
    required this.dimColor,
    required this.barWidth,
    required this.gap,
  });

  final List<double> bars;
  final double progress;
  final Color color;
  final Color dimColor;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0) return;
    final n = bars.length;
    // largeur de barre adaptée à l'espace disponible
    final step = size.width / n;
    final w = (step - gap).clamp(1.5, barWidth + 1.0);
    final played = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    final rest = Paint()
      ..color = dimColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    final midY = size.height / 2;
    final maxH = size.height - w;
    for (var i = 0; i < n; i++) {
      final x = step * i + step / 2;
      final h = (bars[i].clamp(0.08, 1.0) * maxH).clamp(w, maxH);
      final p = (i + 0.5) / n <= progress ? played : rest;
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter o) =>
      o.progress != progress ||
      o.bars != bars ||
      o.color != color ||
      o.dimColor != dimColor;
}
