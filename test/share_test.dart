import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_app/config/share_config.dart';
import 'package:muslim_app/models/hadith.dart';
import 'package:muslim_app/screens/hadith_detail_screen.dart';
import 'package:muslim_app/services/share_content.dart';
import 'package:muslim_app/services/share_gateway.dart';
import 'package:muslim_app/services/share_service.dart';
import 'package:muslim_app/widgets/share/hadith_share_card.dart';
import 'package:muslim_app/widgets/share/quiz_score_share_card.dart';

class SharedRecord {
  final String text;
  final String subject;
  final Uint8List? image;
  final Rect? origin;
  const SharedRecord(this.text, this.subject, this.image, this.origin);
}

class FakeShareGateway implements ShareGateway {
  final List<SharedRecord> shared = [];

  @override
  Future<void> share({
    required String text,
    required String subject,
    Uint8List? image,
    Rect? origin,
  }) async =>
      shared.add(SharedRecord(text, subject, image, origin));
}

class FakeRenderer implements ShareImageRenderer {
  FakeRenderer({this.fail = false});
  final bool fail;
  final List<Widget> rendered = [];

  @override
  Future<Uint8List> render(Widget card, {BuildContext? context}) async {
    if (fail) throw StateError('rendu impossible');
    rendered.add(card);
    return Uint8List.fromList([1, 2, 3]);
  }
}

const _hadith = Hadith(
  id: '1',
  text: 'Les actions ne valent que par les intentions.',
  source: 'Rapporté par al-Bukhârî et Muslim',
  reviewed: true,
  grade: 'Authentique',
);

final _longText = List.filled(120, 'mot').join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareContent', () {
    test('hadith : texte intégral, source, degré, signature', () {
      final m = ShareContent.hadith(_hadith);
      expect(m.text, '« Les actions ne valent que par les intentions. »\n'
          '(Rapporté par al-Bukhârî et Muslim · Authentique)\n\n'
          '${ShareConfig.signature()}');
      expect(m.subject, 'Un hadith partagé depuis Deen');
    });

    test('hadith long : jamais tronqué dans le message', () {
      final long = Hadith(id: '2', text: _longText, source: '', reviewed: true);
      final m = ShareContent.hadith(long);
      expect(m.text, contains(_longText));
      expect(m.text, isNot(contains('\n\n\n')));
    });

    test('signature : avec ou sans lien App Store', () {
      expect(ShareConfig.signature(url: null),
          '— Partagé depuis Deen, l’app pour la prière, le Coran et les hadiths.');
      expect(ShareConfig.signature(url: 'https://apps.apple.com/app/id1'),
          endsWith('hadiths : https://apps.apple.com/app/id1'));
      expect(ShareContent.hadith(_hadith, url: 'https://x.y').text,
          endsWith(': https://x.y'));
    });

    test('score du quiz : phrase d’invitation et niveau', () {
      final m = ShareContent.quizScore(correct: 8, total: 10, level: 'Intermédiaire');
      expect(m.text, startsWith('J’ai obtenu 8/10 au quiz de Deen (niveau Intermédiaire). '
          'Concurrençons-nous dans la science qu’Allah nous a offerte ! À toi de jouer !'));
      expect(m.text, endsWith(ShareConfig.signature()));
      expect(ShareContent.quizScore(correct: 3, total: 5).text,
          startsWith('J’ai obtenu 3/5 au quiz de Deen. '));
    });
  });

  group('HadithShareCard', () {
    test('extrait : court inchangé, long coupé à un mot avec « … »', () {
      expect(HadithShareCard.excerpt('Court.'), ('Court.', false));
      final (text, cut) = HadithShareCard.excerpt(_longText);
      expect(cut, isTrue);
      expect(text, endsWith('mot…'));
      expect(text.length, lessThanOrEqualTo(HadithShareCard.maxChars + 1));
      expect(HadithShareCard.fontSizeFor('court'), greaterThan(HadithShareCard.fontSizeFor(_longText)));
    });

    for (final (name, hadith) in [
      ('court', _hadith),
      ('long', Hadith(id: '3', text: _longText, source: 'Source', reviewed: true)),
    ]) {
      testWidgets('carte hadith ($name) : 360×450 sans débordement', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Center(child: HadithShareCard(hadith: hadith)),
        ));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(HadithShareCard)), const Size(360, 450));
        expect(find.text('Deen'), findsOneWidget);
        if (name == 'long') expect(find.text('Suite dans le message'), findsOneWidget);
      });
    }

    testWidgets('carte score : chiffres, niveau, invitation', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(child: QuizScoreShareCard(correct: 8, total: 10, level: 'Avancé')),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Niveau Avancé'), findsOneWidget);
      expect(find.text(ShareContent.quizInvitation), findsOneWidget);
    });
  });

  group('ShareService', () {
    test('texte + image ; point d’ancrage transmis (iPad)', () async {
      final gateway = FakeShareGateway();
      final renderer = FakeRenderer();
      const origin = Rect.fromLTWH(10, 10, 40, 40);
      await ShareService(gateway: gateway, renderer: renderer)
          .shareHadith(_hadith, origin: origin);
      final s = gateway.shared.single;
      expect(s.text, ShareContent.hadith(_hadith).text);
      expect(s.image, isNotNull);
      expect(s.origin, origin);
      expect(renderer.rendered.single, isA<HadithShareCard>());
    });

    test('[⚠️] image impossible : le texte est partagé quand même', () async {
      final gateway = FakeShareGateway();
      await ShareService(gateway: gateway, renderer: FakeRenderer(fail: true))
          .shareQuizScore(correct: 7, total: 10);
      expect(gateway.shared.single.image, isNull);
      expect(gateway.shared.single.text, startsWith('J’ai obtenu 7/10'));
    });
  });

  testWidgets('rendu réel (screenshot) : une image PNG 1080 × 1350', (tester) async {
    late Uint8List png;
    await tester.runAsync(() async {
      png = await ScreenshotRenderer().render(const HadithShareCard(hadith: _hadith));
    });
    // Signature PNG, puis largeur et hauteur (octets 16 à 23, gros-boutiste).
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    final data = ByteData.sublistView(png);
    expect([data.getUint32(16), data.getUint32(20)], [1080, 1350]);
  });

  testWidgets('écran du hadith : le bouton Partager ouvre le partage', (tester) async {
    final gateway = FakeShareGateway();
    await tester.pumpWidget(MaterialApp(
      home: HadithDetailScreen(
        hadith: _hadith,
        shareService: ShareService(gateway: gateway, renderer: FakeRenderer()),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('Partager le hadith'));
    await tester.pump();
    expect(gateway.shared, hasLength(1));
    expect(gateway.shared.single.text, contains('Les actions ne valent'));
    expect(gateway.shared.single.origin, isNotNull);
  });
}
