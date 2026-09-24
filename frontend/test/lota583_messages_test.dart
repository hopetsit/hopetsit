// v583 — lot A du chantier du 24/09 : les deux pages de messages (captures de
// Daniel du 23/09). Sans écran ni serveur : une session de chat FACTICE.
//
// Ce qui est vérifié :
//   · la pilule d'en-tête (« Suivre en direct » / « Partager ma position »)
//     n'est JAMAIS coupée : 9 langues, 320 et 375 px, 2 lignes au plus, aucune
//     exception de débordement, aucun « … » ;
//   · la carte de la liste ressort à la couleur du rôle : liseré gauche plein,
//     anneau d'avatar, nom et aperçu d'une conversation non lue à l'accent ;
//     la pastille « hors ligne » est une teinte chaude PLEINE (saturation) ;
//   · la conversation porte le fond à pattes DANS son conteneur ; l'heure d'un
//     message reçu est en encre chaude pleine, celle d'un message envoyé en
//     blanc (plus de noir translucide = gris) ;
//   · les libellés courts existent dans les 9 langues.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/localization/v565/chat_i18n.dart';
import 'package:hopetsit/localization/v565/lota583_i18n.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_bubble.dart';
import 'package:hopetsit/views/chat_shared/chat_conversation_body.dart';
import 'package:hopetsit/views/chat_shared/chat_header.dart';
import 'package:hopetsit/views/chat_shared/chat_list_body.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

class _T extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        for (final l in _langs)
          l: {
            ...chatI18n[l]!,
            ...lotA583I18n[l]!,
            'chat_message_deleted': 'deleted',
            'time_minutes_ago': '@count min',
            'time_hours_ago': '@count h',
            'time_days_ago': '@count d',
            'time_just_now': 'now',
          },
      };
}

class _Msg extends ChatMessageBase {
  _Msg({
    required super.id,
    required super.message,
    required super.isFromCurrentUser,
    required super.timestamp,
  }) : super(senderId: isFromCurrentUser ? 'me' : 'peer', senderName: 'x', senderImage: '');
}

class _Conv extends ChatConversationBase {
  _Conv({
    required super.id,
    required super.contactName,
    required super.isOnline,
    required super.unreadCount,
    super.lastSeenAt,
  }) : super(
          contactImage: '',
          lastMessage: 'Bonjour, Rex est prêt.',
          lastMessageTime: DateTime.now(),
        );
}

/// Session factice : seuls les membres lus par les widgets testés existent.
class _FakeSession implements ChatSession {
  _FakeSession({List<ChatConversationBase> convs = const [], List<ChatMessageBase> msgs = const []})
      : conversationsRx = RxList<ChatConversationBase>(convs),
        messagesRx = RxList<ChatMessageBase>(msgs);

  @override
  final RxList<ChatConversationBase> conversationsRx;
  @override
  final RxList<ChatMessageBase> messagesRx;
  @override
  final RxBool isLoading = false.obs;
  @override
  final RxBool isMessagesLoading = false.obs;
  @override
  final RxString errorMessage = ''.obs;
  @override
  final RxBool isPaymentRequired = false.obs;
  @override
  final RxBool isChatLocked = false.obs;
  @override
  final Rx<ChatFeatureFlags> features = const ChatFeatureFlags().obs;
  @override
  final RxBool autoTranslate = false.obs;
  @override
  final RxBool peerOnline = false.obs;
  @override
  final Rxn<DateTime> peerLastSeen = Rxn<DateTime>();
  @override
  final RxMap<String, String> translations = <String, String>{}.obs;
  @override
  final RxSet<String> translating = <String>{}.obs;
  @override
  final ValueNotifier<bool> newChatExpanded = ValueNotifier<bool>(true);
  @override
  final RxString deletedConversationId = ''.obs;
  @override
  String get currentUserId => 'me';
  @override
  Future<void> reloadConversations() async {}
  @override
  Future<bool> deleteConversation(String conversationId) async => true;
  @override
  void setChatVisible(String conversationId, bool visible, {bool markRead = false}) {}
  @override
  Future<void> loadChatMessages(String chatId, {String? contactName, String? contactImage}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _app(Widget home, {String lang = 'fr', Brightness brightness = Brightness.light}) {
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      translations: _T(),
      locale: Locale(lang),
      fallbackLocale: const Locale('en'),
      theme: ThemeData(brightness: brightness),
      home: home,
    ),
  );
}

void _sizeTo(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Vrai si le paragraphe rendu tient dans ses `maxLines` (aucune coupure).
bool _fits(WidgetTester tester, Finder textFinder) {
  final rp = tester.renderObject<RenderParagraph>(textFinder);
  final painter = TextPainter(
    text: rp.text,
    textDirection: rp.textDirection,
    maxLines: rp.maxLines,
    textScaler: rp.textScaler,
  )..layout(maxWidth: rp.size.width);
  final ok = !painter.didExceedMaxLines;
  painter.dispose();
  return ok;
}

/// Hors réseau, google_fonts ne charge aucune police : le rendu retombe sur la
/// police de test (chaque glyphe = 1 em), 2 fois plus large qu'Inter. Pour
/// mesurer les coupures de façon réaliste, on enregistre une police
/// PROPORTIONNELLE du Mac sous les familles que google_fonts demande
/// (« Inter_800 » = Inter gras 800 de InterText).
Future<void> _loadProportionalFonts() async {
  const files = {
    'Inter_800': '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    'Inter_700': '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    'Inter_600': '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    'Inter_500': '/System/Library/Fonts/Supplemental/Arial.ttf',
    'Inter_regular': '/System/Library/Fonts/Supplemental/Arial.ttf',
  };
  for (final e in files.entries) {
    final f = File(e.value);
    if (!f.existsSync()) {
      // ignore: avoid_print
      print('police absente : ${e.value} — mesure avec la police de test (plus large)');
      continue;
    }
    final bytes = await f.readAsBytes();
    final loader = FontLoader(e.key)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadProportionalFonts();
  });
  tearDown(Get.reset);

  group('en-tête de discussion — pilule jamais coupée', () {
    for (final width in [320.0, 375.0]) {
      for (final lang in _langs) {
        testWidgets('$lang à ${width.toInt()} px : suivre + partager', (tester) async {
          _sizeTo(tester, width);
          final session = _FakeSession();
          for (final entry in {
            'cs_pf_pill_follow': ChatRoleTheme.owner,
            'cs_pf_pill_share': ChatRoleTheme.sitter,
          }.entries) {
            await tester.pumpWidget(_app(
              Scaffold(
                appBar: ChatHeaderBar(
                  session: session,
                  theme: entry.value,
                  contactName: 'Camille Durand',
                  contactImage: '',
                  actions: [
                    // `.tr` lu DANS l'arbre, une fois la locale posée.
                    Builder(
                      builder: (_) => PawFollowPill(
                        key: const ValueKey<String>('pill'),
                        label: entry.key.tr,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                body: const SizedBox.shrink(),
              ),
              lang: lang,
            ));
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull, reason: '$lang ${entry.key} $width');
            final label = lotA583I18n[lang]![entry.key]!;
            final textFinder = find.text(label);
            expect(textFinder, findsOneWidget, reason: '$lang ${entry.key}');
            final text = tester.widget<Text>(textFinder);
            expect(text.overflow, isNot(TextOverflow.ellipsis), reason: 'jamais de « … »');
            expect(_fits(tester, textFinder), isTrue,
                reason: '« $label » dépasse 2 lignes en $lang à ${width.toInt()} px');
          }
        });
      }
    }

    testWidgets('ChatHeaderPill (kit) : 2 lignes, sans « … »', (tester) async {
      _sizeTo(tester, 320);
      await tester.pumpWidget(_app(Scaffold(
        appBar: AppBar(actions: [
          ChatHeaderPill(
            icon: Icons.my_location_rounded,
            label: 'Udostępnij moją pozycję na żywo',
            onTap: () {},
            theme: ChatRoleTheme.walker,
          ),
        ]),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      final f = find.text('Udostępnij moją pozycję na żywo');
      expect(tester.widget<Text>(f).overflow, isNot(TextOverflow.ellipsis));
      expect(_fits(tester, f), isTrue);
    });
  });

  group('liste des conversations — couleur du rôle', () {
    testWidgets('liseré, anneau, non-lu à l\'accent, hors ligne chaud', (tester) async {
      _sizeTo(tester, 375);
      final session = _FakeSession(convs: [
        _Conv(id: 'c1', contactName: 'Léa Martin', isOnline: false, unreadCount: 2,
            lastSeenAt: DateTime.now().subtract(const Duration(minutes: 5))),
        _Conv(id: 'c2', contactName: 'Marc Dupont', isOnline: true, unreadCount: 0),
      ]);
      const theme = ChatRoleTheme.owner;
      await tester.pumpWidget(_app(Scaffold(
        body: ChatListBody(session: session, theme: theme, onOpen: (_) {}),
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Léa Martin'), findsOneWidget);
      expect(find.text('Marc Dupont'), findsOneWidget);

      // Anneau d'avatar à la couleur du rôle, sur chaque carte.
      final avatars = tester.widgetList<ChatAvatar>(find.byType(ChatAvatar)).toList();
      expect(avatars.length, 2);
      for (final a in avatars) {
        expect(a.borderColor, theme.accent);
        expect(a.borderWidth, greaterThanOrEqualTo(2.0));
      }

      // Liseré gauche PLEIN (5 px) à la couleur du rôle.
      final bars = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        if (d is! BoxDecoration || d.border is! Border) return false;
        final b = d.border! as Border;
        return b.left.width == 5 && b.left.color == theme.accent;
      });
      expect(bars.length, 2, reason: 'un liseré par carte');

      // Non lu : nom et aperçu à l'accent (mode clair = accent tel quel).
      final leaName = tester.widget<Text>(find.text('Léa Martin'));
      expect(leaName.style?.color, theme.accent);
      final marcName = tester.widget<Text>(find.text('Marc Dupont'));
      expect(marcName.style?.color, AppColors.blackColor);
      final previews = tester.widgetList<Text>(find.text('Bonjour, Rex est prêt.')).toList();
      expect(previews.map((t) => t.style?.color).toSet(),
          {theme.accent, AppColors.greyText});

      // Pastille « hors ligne » : teinte chaude PLEINE (saturation), jamais grise.
      final offline = HSLColor.fromColor(ChatRoleTheme.offline);
      expect(offline.saturation, greaterThan(0.5),
          reason: 'saturation ${offline.saturation.toStringAsFixed(2)}');
      expect(ChatRoleTheme.offline.a, 1.0);
    });
  });

  group('conversation — fond à pattes et encre pleine', () {
    testWidgets('PawPatternBackground DANS le corps, heures en encre pleine', (tester) async {
      _sizeTo(tester, 375);
      final ts = DateTime(2026, 9, 24, 14, 5);
      final session = _FakeSession(msgs: [
        _Msg(id: 'm1', message: 'Bonjour !', isFromCurrentUser: false, timestamp: ts),
        _Msg(id: 'm2', message: 'Salut Léa', isFromCurrentUser: true, timestamp: ts),
      ]);
      const theme = ChatRoleTheme.owner;
      await tester.pumpWidget(_app(Scaffold(
        body: ChatConversationBody(
          session: session,
          theme: theme,
          conversationId: 'c1',
          contactName: 'Léa Martin',
          specialCardBuilder: (_) => null,
          bottomBuilder: () => const SizedBox(height: 8),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byType(PawPatternBackground), findsOneWidget);
      expect(find.byType(ChatMessageBubble), findsNWidgets(2));
      expect(find.byType(PawPatternBackground), findsOneWidget);

      final ctx = tester.element(find.byType(ChatConversationBody));
      final clock = chatClock(ctx, ts);
      final clocks = tester.widgetList<Text>(find.text(clock)).toList();
      expect(clocks.length, 2, reason: 'une heure par bulle');
      final inks = clocks.map((t) => t.style?.color).toSet();
      expect(inks, {Colors.white, AppColors.greyText},
          reason: 'blanc sur ma bulle, encre chaude pleine sur la bulle reçue');
      for (final c in inks) {
        expect(c!.a, 1.0, reason: 'aucune encre translucide');
      }
    });
  });

  test('libellés courts présents dans les 9 langues', () {
    final ref = lotA583I18n['en']!.keys.toSet();
    expect(ref, {'cs_pf_pill_follow', 'cs_pf_pill_share'});
    for (final l in _langs) {
      expect(lotA583I18n[l]?.keys.toSet(), ref, reason: l);
      expect(lotA583I18n[l]!.values.every((v) => v.trim().isNotEmpty), isTrue, reason: l);
    }
  });
}
