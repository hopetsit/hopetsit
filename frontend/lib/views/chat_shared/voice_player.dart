// v565 — point 13 : bulle de message vocal (lecture / pause, barre de
// progression, durée) avec `audioplayers`.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';

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

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final fg = widget.mine ? Colors.white : t.accent;
    final track = widget.mine
        ? Colors.white.withValues(alpha: 0.35)
        : t.accent.withValues(alpha: 0.18);
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
      width: 210.w,
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
                    : t.tintStrong,
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
                  height: 22.h,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      activeTrackColor: fg,
                      inactiveTrackColor: track,
                      thumbColor: fg,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: total.inMilliseconds > 0
                          ? (v) {
                              final target = Duration(
                                milliseconds:
                                    (total.inMilliseconds * v).round(),
                              );
                              _player.seek(target);
                              setState(() => _position = target);
                            }
                          : null,
                    ),
                  ),
                ),
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
