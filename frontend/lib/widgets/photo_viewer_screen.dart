// v573 — visionneuse photo plein écran COMMUNE (fiche animal, galerie animal).
//
// Elle remplace les `Scaffold(backgroundColor: Colors.black, appBar: AppBar(…))`
// bruts qui traînaient dans la fiche animal et dans la galerie : une AppBar
// noire sur fond noir, sans compteur, sans glissement entre les photos.
//
// Ce que fait celle-ci :
//   · fond noir plein écran, aucune AppBar (la photo occupe tout l'écran) ;
//   · bouton fermer ROND translucide en haut à gauche (zone tactile 44 dp) ;
//   · compteur « 3 / 8 » en pilule translucide quand il y a plusieurs photos ;
//   · zoom / déplacement par photo (`InteractiveViewer`), remis à zéro quand on
//     change de photo — sinon la photo suivante arrive déjà zoomée ;
//   · glissement horizontal entre les photos (`PageView`) ;
//   · décodage mémoire borné à la largeur de l'écran (×2 pour le zoom) : on ne
//     décode pas une image de 1600 px dans une vignette, ni 4000 px en plein
//     écran.
//
// AUCUNE nouvelle clé i18n : le compteur est numérique et le bouton fermer
// porte `common_close` (présent dans les 9 langues).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Ouvre la visionneuse sur [urls], en commençant par [initialIndex].
///
/// Les URL vides sont ignorées ; si la liste est vide, rien ne s'ouvre.
void openPhotoViewer(List<String> urls, {int initialIndex = 0}) {
  final List<String> clean =
      urls.where((String u) => u.trim().isNotEmpty).toList(growable: false);
  if (clean.isEmpty) return;
  final int start = initialIndex.clamp(0, clean.length - 1);
  Get.to(
    () => PhotoViewerScreen(urls: clean, initialIndex: start),
    transition: Transition.fadeIn,
    fullscreenDialog: true,
  );
}

class PhotoViewerScreen extends StatefulWidget {
  /// Photos à afficher, dans l'ordre.
  final List<String> urls;

  /// Photo affichée à l'ouverture.
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages;
  late final List<TransformationController> _zooms;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.urls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pages = PageController(initialPage: _index);
    _zooms = List<TransformationController>.generate(
      widget.urls.length,
      (_) => TransformationController(),
      growable: false,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final TransformationController c in _zooms) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int i) {
    // La photo qu'on quitte revient à l'échelle 1 : sinon on retombe dessus
    // zoomée et décadrée.
    if (_index >= 0 && _index < _zooms.length) {
      _zooms[_index].value = Matrix4.identity();
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    // Budget de décodage : la largeur physique de l'écran ×2 (on peut zoomer
    // jusqu'à 4, mais au-delà de ×2 la perte est invisible sur un téléphone).
    final int decodeWidth =
        (mq.size.width * mq.devicePixelRatio * 2).round().clamp(360, 2400);
    final bool multiple = widget.urls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.urls.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (BuildContext context, int i) {
                return Center(
                  child: InteractiveViewer(
                    transformationController: _zooms[i],
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.urls[i],
                      fit: BoxFit.contain,
                      memCacheWidth: decodeWidth,
                      fadeInDuration: const Duration(milliseconds: 120),
                      placeholder: (BuildContext c, String _) => const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      errorWidget: (BuildContext c, String _, Object __) =>
                          const Icon(Icons.broken_image_rounded,
                              color: AppColors.textSecondaryDark, size: 48),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bouton fermer — rond translucide, en haut à gauche.
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            child: _RoundGlassButton(
              key: const ValueKey<String>('photo_viewer_close'),
              icon: Icons.close_rounded,
              tooltip: 'common_close'.tr,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),

          // Compteur « 3 / 8 » — seulement s'il y a plusieurs photos.
          if (multiple)
            Positioned(
              top: mq.padding.top + 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const ValueKey<String>('photo_viewer_counter'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InterText(
                    text: '${_index + 1} / ${widget.urls.length}',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Petit bouton rond « verre » réutilisé par la visionneuse.
class _RoundGlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundGlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: AppColors.cardDark.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
