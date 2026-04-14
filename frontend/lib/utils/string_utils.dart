/// Masks a phone number by showing only the last 4 digits.
/// e.g. "+923007654321" -> "*******4321"
String maskPhoneNumber(String phone) {
  if (phone.isEmpty) return '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) return '*' * digits.length;
  return '*' * (digits.length - 4) + digits.substring(digits.length - 4);
}
