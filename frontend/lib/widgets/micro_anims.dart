import 'dart:math' as math;

import 'package:flutter/material.dart';

/// v540 — micro-animations du handoff design LAP (« Animations CSS ») :
/// [HeartBeat] = keyframes heartBeat (cœur ❤), [ArrowNudge] = arrowNudge
/// (flèches ›), [FadeSlideIn] = entrée en fondu + glissement, à décaler
/// par section pour l'effet cascade.

/// Cœur qui bat : scale 1→1.25→1→1.15→1 sur les 48 premiers % d'un cycle
/// de 1,8 s, puis repos — en boucle (spec handoff).
class HeartBeat extends StatefulWidget {
  const HeartBeat({super.key, required this.child});

  final Widget child;

  @override
  State<HeartBeat> createState() => _HeartBeatState();
}

class _HeartBeatState extends State<HeartBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Flèche qui « pousse » : translateX 0→4→0, 1,4 s ease-in-out, en boucle.
class ArrowNudge extends StatefulWidget {
  const ArrowNudge({super.key, required this.child});

  final Widget child;

  @override
  State<ArrowNudge> createState() => _ArrowNudgeState();
}

class _ArrowNudgeState extends State<ArrowNudge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(4 * math.sin(math.pi * _c.value), 0),
          child: child,
        ),
        child: widget.child,
      );
}

/// Entrée d'une section : fondu + remontée de 16 px (450 ms, ease-out),
/// démarrée après [delay] pour un effet cascade.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, this.delay = Duration.zero, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final CurvedAnimation _eased =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _eased,
        child: AnimatedBuilder(
          animation: _eased,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, 16 * (1 - _eased.value)),
            child: child,
          ),
          child: widget.child,
        ),
      );
}

/// Pulsation douce (scale 1→1.06→1, 1,6 s, en boucle) — attire l'œil sur un
/// bouton d'action sans l'agiter (utilisé sur « Reprendre »).
class SoftPulse extends StatefulWidget {
  const SoftPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SoftPulse> createState() => _SoftPulseState();
}

class _SoftPulseState extends State<SoftPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 1.06).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
