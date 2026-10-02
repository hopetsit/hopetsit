// 607 (BOB, 02/10/2026) — pilote de vérification interne, DEBUG SEULEMENT.
//
// Pourquoi : le Mac est verrouillé la nuit, aucun clic n'est possible dans le
// simulateur, et `flutter test integration_test` réinstalle l'app (fenêtres
// système). Ce pilote lit des ordres dans Documents/hps_cmd.json (écrits par
// l'hôte via le dossier du simulateur) et injecte de VRAIS appuis dans l'app
// qui tourne : tap, glisser, texte, retour, route. Il n'est démarré que par
// main.dart sous `!kReleaseMode` + clé locale `hps_dev_remote` : jamais dans
// une app de store.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:path_provider/path_provider.dart';

int _pointer = 9000;

Future<void> _tap(double x, double y, {int holdMs = 70}) async {
  final p = Offset(x, y);
  final id = ++_pointer;
  final b = GestureBinding.instance;
  b.handlePointerEvent(PointerAddedEvent(pointer: id, position: p));
  b.handlePointerEvent(PointerDownEvent(pointer: id, position: p));
  await Future<void>.delayed(Duration(milliseconds: holdMs));
  b.handlePointerEvent(PointerUpEvent(pointer: id, position: p));
  b.handlePointerEvent(PointerRemovedEvent(pointer: id, position: p));
}

Future<void> _drag(double x1, double y1, double x2, double y2) async {
  final id = ++_pointer;
  final b = GestureBinding.instance;
  var p = Offset(x1, y1);
  b.handlePointerEvent(PointerAddedEvent(pointer: id, position: p));
  b.handlePointerEvent(PointerDownEvent(pointer: id, position: p));
  const n = 12;
  for (var i = 1; i <= n; i++) {
    final q = Offset(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    b.handlePointerEvent(PointerMoveEvent(pointer: id, position: q, delta: q - p));
    p = q;
  }
  b.handlePointerEvent(PointerUpEvent(pointer: id, position: p));
  b.handlePointerEvent(PointerRemovedEvent(pointer: id, position: p));
}

/// Centre (pixels logiques) du premier Text visible qui contient [needle].
Offset? _findText(String needle) {
  Offset? found;
  void visit(Element e) {
    if (found != null) return;
    final w = e.widget;
    String? s;
    if (w is Text) s = w.data ?? w.textSpan?.toPlainText();
    if (w is RichText) s = w.text.toPlainText();
    if (s != null && s.contains(needle)) {
      final r = e.renderObject;
      if (r is RenderBox && r.hasSize && r.attached) {
        final c = r.localToGlobal(r.size.center(Offset.zero));
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final size = view.physicalSize / view.devicePixelRatio;
        if (c.dx >= 0 && c.dy >= 0 && c.dx <= size.width && c.dy <= size.height) {
          found = c;
          return;
        }
      }
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

void startDevRemote607() {
  var last = -1;
  var busy = false;
  Timer.periodic(const Duration(milliseconds: 300), (_) async {
    if (busy) return;
    busy = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/hps_cmd.json');
      if (!f.existsSync()) return;
      final Map<String, dynamic> c = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final seq = (c['seq'] as num?)?.toInt() ?? -1;
      if (seq == last) return;
      last = seq;
      var res = 'ok';
      final op = c['op'];
      double d(String k) => (c[k] as num).toDouble();
      if (op == 'tap') {
        await _tap(d('x'), d('y'));
      } else if (op == 'long') {
        await _tap(d('x'), d('y'), holdMs: 900);
      } else if (op == 'drag') {
        await _drag(d('x1'), d('y1'), d('x2'), d('y2'));
      } else if (op == 'tapText') {
        final o = _findText(c['text'] as String);
        if (o == null) {
          res = 'introuvable';
        } else {
          await _tap(o.dx, o.dy);
          res = 'ok ${o.dx.round()},${o.dy.round()}';
        }
      } else if (op == 'has') {
        res = _findText(c['text'] as String) == null ? 'non' : 'oui';
      } else if (op == 'route') {
        await DeepLinkService.instance.openRoute(c['route'] as String);
      } else if (op == 'back') {
        Get.back();
      }
      File('${dir.path}/hps_ack.txt').writeAsStringSync('$seq $res');
    } catch (e) {
      // pilote de vérification : une erreur ne doit jamais gêner l'app
    } finally {
      busy = false;
    }
  });
}
