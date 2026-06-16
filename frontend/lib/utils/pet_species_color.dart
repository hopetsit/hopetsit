import 'package:flutter/material.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// v428 — couleur d'accent par espèce pour la fiche animal + la carte
/// « Mes animaux ». Remplace la rotation d'index par une teinte stable et
/// signifiante : chien → orange, chat → bleu, reptile/nac → jaune,
/// oiseau → vert, rongeur/lapin → rose, cheval → violet, défaut → orange.
///
/// Accepte aussi bien le token canonique (dog/cat/…) que les valeurs
/// free-text saisies dans les anciennes locales (chien/chat/perro/…).
Color petSpeciesColor(String? category) {
  final c = (category ?? '').trim().toLowerCase();

  // Chien
  const dog = {
    'dog', 'chien', 'perro', 'hund', 'cane', 'cão', 'cao'
  };
  // Chat
  const cat = {
    'cat', 'chat', 'gato', 'katze', 'gatto'
  };
  // Reptile / NAC
  const reptile = {
    'reptile', 'reptil', 'rettile', 'réptil', 'reptilien', 'nac', 'small'
  };
  // Oiseau
  const bird = {
    'bird', 'oiseau', 'pájaro', 'pajaro', 'vogel', 'uccello', 'pássaro',
    'passaro'
  };
  // Rongeur / lapin
  const rodent = {
    'rabbit', 'lapin', 'conejo', 'kaninchen', 'coniglio', 'coelho',
    'rongeur', 'rodent', 'roedor', 'nager', 'roditore', 'hamster',
    'guineapig', 'guinea_pig'
  };
  // Cheval
  const horse = {
    'horse', 'cheval', 'caballo', 'pferd', 'cavallo', 'cavalo'
  };

  if (dog.contains(c)) return AppColors.primaryColor; // orange
  if (cat.contains(c)) return const Color(0xFF2563EB); // bleu
  if (reptile.contains(c)) return const Color(0xFFE8A00A); // jaune/doré
  if (bird.contains(c)) return const Color(0xFF16A34A); // vert
  if (rodent.contains(c)) return const Color(0xFFEC4899); // rose
  if (horse.contains(c)) return const Color(0xFF8B5CF6); // violet

  return AppColors.primaryColor; // défaut : orange
}

/// Emoji d'espèce pour les chips de sélection (édition profil) et les petites
/// pastilles d'animaux acceptés/promenés sur les cartes de recherche owner.
/// Accepte le token canonique (dog/cat/small/nac/bird/rodent/reptile/horse) ou
/// les valeurs free-text multilingues (chien/chat/perro…).
String petSpeciesEmoji(String? category) {
  final c = (category ?? '').trim().toLowerCase();

  const dog = {'dog', 'chien', 'perro', 'hund', 'cane', 'cão', 'cao'};
  const cat = {'cat', 'chat', 'gato', 'katze', 'gatto'};
  const bird = {
    'bird', 'oiseau', 'pájaro', 'pajaro', 'vogel', 'uccello', 'pássaro',
    'passaro'
  };
  const rodent = {
    'rabbit', 'lapin', 'conejo', 'kaninchen', 'coniglio', 'coelho',
    'rongeur', 'rodent', 'roedor', 'nager', 'roditore', 'hamster',
    'guineapig', 'guinea_pig'
  };
  const reptile = {'reptile', 'reptil', 'rettile', 'réptil', 'reptilien'};
  const horse = {'horse', 'cheval', 'caballo', 'pferd', 'cavallo', 'cavalo'};
  // NAC / petits animaux : pas d'emoji d'espèce unique → patte générique.
  const small = {'small', 'nac', 'petit'};

  if (dog.contains(c)) return '🐕';
  if (cat.contains(c)) return '🐈';
  if (bird.contains(c)) return '🐦';
  if (rodent.contains(c)) return '🐹';
  if (reptile.contains(c)) return '🦎';
  if (horse.contains(c)) return '🐴';
  if (small.contains(c)) return '🐾';

  return '🐾'; // défaut : patte
}
