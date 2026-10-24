// 620 (PAM, 24/10/2026 — Crashlytics du 24/10 : « NetworkImage… HTTP request
// failed », 73 plantages, 3 utilisateurs, 23.1.587) — IMAGE RÉSEAU AVEC REPLI.
//
// Une photo qui répond 401 / 404 (ancien hôte, lien expiré, photo supprimée)
// ne doit JAMAIS faire remonter une erreur : elle se remplace par une patte
// discrète à la couleur de l'écran. Deux formes :
//   · `NetImage620`           : widget (= `Image.network` + `errorBuilder` +
//                               fondu de chargement) ;
//   · `netImageProvider620()` : `ImageProvider` pour `DecorationImage` /
//                               `CircleAvatar`, à coupler avec `onError:` /
//                               `onBackgroundImageError:` (`netImageOnError620`).
// `isNetworkImageError620` sert à `FlutterError.onError` (main.dart) pour
// classer ces erreurs NON FATALES dans Crashlytics.
import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// Vrai pour une erreur de chargement d'image réseau (jamais un plantage).
bool isNetworkImageError620(Object? error) {
  if (error == null) return false;
  if (error is NetworkImageLoadException) return true;
  final t = error.toString();
  return t.contains('NetworkImageLoadException') ||
      t.contains('HTTP request failed') ||
      t.contains('Invalid image data') ||
      t.contains('Image provider') ||
      t.contains('_network_image_io') ||
      t.contains('Codec failed') ||
      t.contains('ImageCodecException');
}

/// Repli : patte discrète sur fond teinté (jamais gris).
class NetImageFallback620 extends StatelessWidget {
  const NetImageFallback620({
    super.key,
    this.color,
    this.iconSize,
    this.icon = Icons.pets_rounded,
  });

  final Color? color;
  final double? iconSize;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? AppColors.primaryColor;
    return ColoredBox(
      color: tone.withValues(alpha: 0.10),
      child: Center(
        child: LayoutBuilder(
          builder: (ctx, c) {
            final double side =
                c.hasBoundedWidth && c.hasBoundedHeight ? (c.biggest.shortestSide) : 48;
            return Icon(icon,
                size: iconSize ?? (side * 0.42).clamp(12, 64),
                color: tone.withValues(alpha: 0.55));
          },
        ),
      ),
    );
  }
}

/// `Image.network` qui ne lève jamais : repli + fondu.
class NetImage620 extends StatelessWidget {
  const NetImage620(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.fallbackColor,
    this.fallback,
    this.cacheWidth,
    this.cacheHeight,
    this.headers,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Color? fallbackColor;
  final Widget? fallback;
  final int? cacheWidth;
  final int? cacheHeight;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    final Widget fb = fallback ?? NetImageFallback620(color: fallbackColor);
    final u = url.trim();
    if (u.isEmpty || !(u.startsWith('http://') || u.startsWith('https://'))) {
      return SizedBox(width: width, height: height, child: fb);
    }
    return Image.network(
      u,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      headers: headers,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => SizedBox(width: width, height: height, child: fb),
      frameBuilder: (ctx, child, frame, sync) {
        if (sync || frame != null) return child;
        return SizedBox(width: width, height: height, child: fb);
      },
    );
  }
}

/// `ImageProvider` réseau (null si l'URL est vide / non http) — à coupler avec
/// `onError: netImageOnError620` (DecorationImage) ou
/// `onBackgroundImageError: netImageOnError620` (CircleAvatar).
ImageProvider? netImageProvider620(String? url, {int? maxWidth}) {
  final u = (url ?? '').trim();
  if (u.isEmpty || !(u.startsWith('http://') || u.startsWith('https://'))) return null;
  final ImageProvider p = NetworkImage(u);
  if (maxWidth != null && maxWidth > 0) {
    return ResizeImage(p, width: maxWidth);
  }
  return p;
}

/// Absorbe l'erreur (déjà rendue non fatale) : rien à faire, le widget hôte
/// montre son enfant / sa couleur de fond.
void netImageOnError620(Object error, StackTrace? stack) {}
