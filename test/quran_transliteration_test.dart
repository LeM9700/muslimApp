import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_app/models/quran_models.dart';
import 'package:muslim_app/utils/quran_transliteration.dart';

void main() {
  group('QuranTransliteration.toFrench (versets réels de Quran.com)', () {
    test('‘ayn, hamza et voyelles longues', () {
      expect(QuranTransliteration.toFrench('Alhamdu lillahi rabbi alAAalameen'),
          'Alhamdu lillahi rabbi al‘alamîn');
      expect(QuranTransliteration.toFrench('Bismi Allahi arrahmani arraheem'),
          'Bismi Allahi arrahmani arrahîm');
      expect(
          QuranTransliteration.toFrench(
              'Allatheena yu/minoona bilghaybiwayuqeemoona assalata'),
          'Allathîna yu’minûna bilghaybiwayuqîmûna assalata');
      expect(QuranTransliteration.toFrench('Lam yalid walam yoolad'),
          'Lam yalid walam yûlad');
      expect(
          QuranTransliteration.toFrench(
              'Khatama Allahu AAala quloobihimwaAAala samAAihim'),
          'Khatama Allahu ‘ala qulûbihimwa‘ala sam‘ihim');
    });

    test('balises et espaces superflus retirés ; déjà lisible : inchangé', () {
      expect(QuranTransliteration.toFrench('  Qul <b>huwa</b>   Allahu ahad '),
          'Qul huwa Allahu ahad');
      expect(QuranTransliteration.toFrench('Alif-lam-meem'), 'Alif-lam-mîm');
    });
  });

  group('Verse.fromApi', () {
    Map<String, dynamic> verse(List<Map<String, dynamic>> translations) => {
          'id': 1,
          'verse_number': 2,
          'verse_key': '1:2',
          'text_uthmani': 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
          'translations': translations,
        };

    test('sépare traduction et phonétique, quel que soit l’ordre', () {
      final fr = {'resource_id': 136, 'text': 'Louange à Allah<sup foot_note=1>1</sup>'};
      final tr = {'resource_id': 57, 'text': 'Alhamdu lillahi rabbi alAAalameen'};
      for (final order in [
        [fr, tr],
        [tr, fr],
      ]) {
        final v = Verse.fromApi(verse(order));
        expect(v.translationText, 'Louange à Allah');
        expect(v.transliteration, 'Alhamdu lillahi rabbi al‘alamîn');
      }
    });

    test('sans phonétique (ancienne réponse) : null, la traduction reste', () {
      final v = Verse.fromApi(verse([
        {'resource_id': 136, 'text': 'Louange à Allah'},
      ]));
      expect(v.transliteration, isNull);
      expect(v.translationText, 'Louange à Allah');
      expect(Verse.fromApi(verse([])).translationText, isNull);
    });
  });
}
