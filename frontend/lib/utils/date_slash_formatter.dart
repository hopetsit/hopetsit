import 'package:flutter/services.dart';

/// v527 — retour testeur (Jose) : « quand je tape la date, je dois mettre
/// les "/" à la main ». Formatter JJ/MM/AAAA : insère automatiquement les
/// slashs après le jour (2 chiffres) et le mois (4 chiffres), limite la
/// saisie à 8 chiffres, et ne réinsère PAS le slash quand on efface
/// (sinon backspace reste bloqué sur le slash).
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
