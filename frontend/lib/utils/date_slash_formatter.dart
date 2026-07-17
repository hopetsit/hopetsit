import 'package:flutter/services.dart';

/// v527 — retour testeur (Jose) : « quand je tape la date, je dois mettre
/// les "/" à la main ». Formatter JJ/MM/AAAA : insère automatiquement les
/// slashs après le jour (2 chiffres) et le mois (4 chiffres), limite la
/// saisie à 8 chiffres, et ne réinsère PAS le slash quand on efface
/// (sinon backspace reste bloqué sur le slash).
/// v527 — retour Jose (R3-9) : parse STRICT d'une date saisie en JJ/MM/AAAA.
/// Rejette les dates impossibles (31/02/2000…) en vérifiant que le DateTime
/// reconstruit correspond bien aux composants saisis. Année bornée 1900..2100.
/// Retourne null si la chaîne n'est pas une date réelle.
DateTime? parseDdMmYyyy(String s) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (year < 1900 || year > 2100) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // DateTime "normalise" les débordements (31/02 → 02/03) : on rejette.
  if (d.year != year || d.month != month || d.day != day) return null;
  return d;
}

/// v527 — retour Jose (R3-9) : âge en années RÉVOLUES par rapport à
/// aujourd'hui (négatif si la date est dans le futur).
int ageInYears(DateTime birth) {
  final now = DateTime.now();
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age--;
  }
  return age;
}

class DateSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final growing = newValue.text.length >= oldValue.text.length;
    final buf = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buf.write(limited[i]);
      final atSlashPos = i == 1 || i == 3;
      final hasMore = i < limited.length - 1;
      if (atSlashPos && (hasMore || growing)) buf.write('/');
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
