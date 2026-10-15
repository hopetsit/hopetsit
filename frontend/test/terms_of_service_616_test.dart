// v616 (ZOE, 15/10/2026) — CGU 2.4 : clause « Responsabilité individuelle et
// conformité aux législations applicables » demandée par Daniel le 14/10.
// Le texte français est repris MOT POUR MOT ; les 5 autres langues portent une
// traduction juridique sobre ; ko / ja / pl retombent sur l'anglais.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/data/static/terms_of_service.dart';

void main() {
  test('termsVersion = 2.4 et chaque langue annonce la version 2.4', () {
    expect(termsVersion, '2.4');
    for (final l in ['en', 'fr', 'es', 'de', 'it', 'pt']) {
      final t = termsOfServiceForLocale(l);
      expect(RegExp(r'(Version|Versión|Versione|Versão) 2\.4').hasMatch(t), isTrue,
          reason: '$l : en-tête « Version 2.4 » absent');
      expect(RegExp(r'(Version|Versión|Versione|Versão) 2\.3').hasMatch(t), isFalse,
          reason: '$l : il reste un « 2.3 »');
    }
  });

  const title = {
    'en': '## 8b. Individual responsibility and compliance with applicable laws',
    'fr': '## 8 ter. Responsabilité individuelle et conformité aux législations applicables',
    'es': '## 8 ter. Responsabilidad individual y cumplimiento de la legislación aplicable',
    'de': '## 8b. Eigenverantwortung und Einhaltung der anwendbaren Gesetze',
    'it': '## 8 ter. Responsabilità individuale e conformità alle normative applicabili',
    'pt': '## 8-B. Responsabilidade individual e conformidade com a legislação aplicável',
  };
  const dsa = {
    'en': 'Digital Services Act',
    'fr': 'Digital Services Act',
    'es': 'Ley de Servicios Digitales',
    'de': 'Gesetz über digitale Dienste',
    'it': 'Digital Services Act',
    'pt': 'Regulamento dos Serviços Digitais',
  };
  for (final entry in title.entries) {
    test('${entry.key} : clause responsabilité individuelle + règlement 2022/2065', () {
      final t = termsOfServiceForLocale(entry.key);
      expect(t, contains(entry.value));
      expect(t, contains('2022/2065'));
      expect(t, contains(dsa[entry.key]!));
      // La clause est placée avant l'article 9 (réservation).
      expect(t.indexOf(entry.value), lessThan(t.indexOf('\n## 9. ')));
      // Une seule fois.
      expect(entry.value.allMatches(t).length, 1);
    });
  }

  test('fr : les 7 paragraphes de Daniel, mot pour mot', () {
    final fr = termsOfServiceForLocale('fr');
    const paras = [
      "Chaque utilisateur de HoPetSit, qu'il soit particulier ou professionnel, est personnellement responsable de vérifier que les activités et prestations qu'il propose ou réalise sont légalement autorisées dans son pays de résidence et dans le pays où elles sont exercées.",
      "Il s'engage à respecter l'ensemble des lois et réglementations locales, nationales et internationales applicables, notamment en matière de qualifications, diplômes, certifications, autorisations administratives, déclarations professionnelles, obligations fiscales et sociales, assurances et protection du bien-être animal.",
      "L'inscription sur HoPetSit et la génération de documents de facturation ne constituent en aucun cas une autorisation légale d'exercer.",
      "HoPetSit intervient exclusivement en qualité de plateforme numérique de mise en relation et ne constitue pas l'employeur des prestataires indépendants.",
      "Conformément à l'article 8 du règlement européen (UE) 2022/2065 (Digital Services Act), les fournisseurs de services intermédiaires concernés ne sont pas soumis à une obligation générale de surveillance des informations qu'ils transmettent ou stockent.",
      "Chaque utilisateur demeure responsable des conséquences de ses propres manquements à la réglementation applicable, sans préjudice des obligations légales propres à HoPetSit, notamment en matière de traitement des signalements, de sécurité et de coopération avec les autorités compétentes.",
      "Cette clause s'applique sous réserve des dispositions impératives en vigueur dans chaque juridiction.",
    ];
    var last = -1;
    for (final p in paras) {
      final i = fr.indexOf(p);
      expect(i, greaterThan(last), reason: 'paragraphe absent ou dans le désordre : $p');
      last = i;
    }
  });

  test('ko / ja / pl retombent sur l\'anglais (clause comprise)', () {
    for (final l in ['ko', 'ja', 'pl']) {
      expect(termsOfServiceForLocale(l), termsOfServiceForLocale('en'));
      expect(termsOfServiceForLocale(l), contains('2022/2065'));
    }
  });
}
