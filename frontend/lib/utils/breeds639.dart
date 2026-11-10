// 639 — races courantes proposées sur la fiche animal (chien / chat).
//
// La race reste un champ LIBRE et FACULTATIF : ces listes ne servent qu'à
// suggérer, le serveur reçoit toujours une simple chaîne (`breed`). Aucune
// race n'est imposée, aucune validation n'en dépend.
//
// Chaque entrée porte un nom anglais et un nom français ; le français est
// montré quand l'app est en français, l'anglais dans les autres langues (les
// noms de races sont très largement internationaux).

/// Une race suggérée (nom anglais + nom français).
class Breed639 {
  final String en;
  final String fr;
  const Breed639(this.en, this.fr);

  /// Nom affiché (et écrit dans le champ) pour la langue [lang].
  String label(String lang) => lang.toLowerCase().startsWith('fr') ? fr : en;
}

/// ~25 races de chien courantes (+ « Croisé »).
const List<Breed639> dogBreeds639 = <Breed639>[
  Breed639('Labrador Retriever', 'Labrador'),
  Breed639('Golden Retriever', 'Golden Retriever'),
  Breed639('German Shepherd', 'Berger allemand'),
  Breed639('French Bulldog', 'Bouledogue français'),
  Breed639('Australian Shepherd', 'Berger australien'),
  Breed639('Belgian Malinois', 'Berger belge malinois'),
  Breed639('Border Collie', 'Border Collie'),
  Breed639('Cavalier King Charles', 'Cavalier King Charles'),
  Breed639('Chihuahua', 'Chihuahua'),
  Breed639('Yorkshire Terrier', 'Yorkshire Terrier'),
  Breed639('Jack Russell Terrier', 'Jack Russell'),
  Breed639('Beagle', 'Beagle'),
  Breed639('Poodle', 'Caniche'),
  Breed639('Dachshund', 'Teckel'),
  Breed639('Shih Tzu', 'Shih Tzu'),
  Breed639('Siberian Husky', 'Husky sibérien'),
  Breed639('Cocker Spaniel', 'Cocker'),
  Breed639('Staffordshire Bull Terrier', 'Staffie'),
  Breed639('American Staffordshire Terrier', 'American Staff'),
  Breed639('Pomeranian', 'Spitz nain'),
  Breed639('Boxer', 'Boxer'),
  Breed639('Rottweiler', 'Rottweiler'),
  Breed639('Bernese Mountain Dog', 'Bouvier bernois'),
  Breed639('Maltese', 'Bichon maltais'),
  Breed639('Shiba Inu', 'Shiba Inu'),
  Breed639('Mixed breed', 'Croisé'),
];

/// ~15 races de chat courantes (+ « Croisé »).
const List<Breed639> catBreeds639 = <Breed639>[
  Breed639('Domestic Shorthair', 'Européen'),
  Breed639('Maine Coon', 'Maine Coon'),
  Breed639('Bengal', 'Bengal'),
  Breed639('British Shorthair', 'British Shorthair'),
  Breed639('Ragdoll', 'Ragdoll'),
  Breed639('Siamese', 'Siamois'),
  Breed639('Persian', 'Persan'),
  Breed639('Sphynx', 'Sphynx'),
  Breed639('Birman', 'Sacré de Birmanie'),
  Breed639('Norwegian Forest Cat', 'Norvégien'),
  Breed639('Siberian', 'Sibérien'),
  Breed639('Chartreux', 'Chartreux'),
  Breed639('Russian Blue', 'Bleu russe'),
  Breed639('Scottish Fold', 'Scottish Fold'),
  Breed639('Abyssinian', 'Abyssin'),
  Breed639('Mixed breed', 'Croisé'),
];

/// Liste de l'espèce [species] (jeton du formulaire : 'Dog', 'Cat', …).
/// Toute autre espèce (oiseau, lapin, autre) → liste vide : pas de suggestion.
List<Breed639> breedsFor639(String? species) {
  switch ((species ?? '').trim().toLowerCase()) {
    case 'dog':
      return dogBreeds639;
    case 'cat':
      return catBreeds639;
    default:
      return const <Breed639>[];
  }
}

const Map<String, String> _accents639 = <String, String>{
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ñ': 'n',
};

/// Minuscules, sans accents, espaces réduits — pour comparer une saisie libre.
String normBreed639(String s) {
  final b = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    b.write(_accents639[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Noms à proposer pour [species] dans la langue [lang], selon la saisie [query] :
///  * saisie vide ou égale à une race suggérée (de cette espèce ou de
///    l'autre, après un changement d'espèce) → toute la liste ;
///  * sinon → les races dont le nom (français OU anglais) contient la saisie ;
///  * aucune correspondance, ou espèce sans liste → liste vide (rien à montrer,
///    la saisie libre continue).
List<String> breedSuggestions639(String? species, String query, String lang) {
  final all = breedsFor639(species);
  if (all.isEmpty) return const <String>[];
  final q = normBreed639(query);
  if (q.isEmpty) return all.map((b) => b.label(lang)).toList();
  bool known(List<Breed639> l) =>
      l.any((b) => normBreed639(b.en) == q || normBreed639(b.fr) == q);
  List<String> whole() => all.map((b) => b.label(lang)).toList();
  // Race de la liste déjà choisie → toute la liste, pour pouvoir en changer.
  if (known(all)) return whole();
  final hits = all
      .where((b) =>
          normBreed639(b.en).contains(q) || normBreed639(b.fr).contains(q))
      .map((b) => b.label(lang))
      .toList();
  if (hits.isNotEmpty) return hits;
  // Rien ne correspond, mais la saisie est une race suggérée de l'AUTRE
  // espèce (on vient de passer de chien à chat avec « Labrador » encore dans
  // le champ) : on propose les races de la nouvelle espèce.
  if (known(dogBreeds639) || known(catBreeds639)) return whole();
  return const <String>[];
}

/// Vrai si [query] désigne la race affichée [label] (accents/casse ignorés).
bool sameBreed639(String query, String label) =>
    normBreed639(query).isNotEmpty && normBreed639(query) == normBreed639(label);
