import 'dart:math';

/// مولّد معرّفات فريد قصير للحسابات والعناصر المحلية.
String newId(String prefix) {
  final rnd = Random.secure();
  final entropy = rnd.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}$entropy';
}
