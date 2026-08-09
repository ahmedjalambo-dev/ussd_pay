import 'dart:math';

/// Generates local record ids.
///
/// A timestamp plus randomness is enough: ids never leave the device, so there
/// is nothing to coordinate with. Avoids pulling in a uuid dependency.
String newId() {
  final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = Random().nextInt(1 << 32).toRadixString(36);
  return '$micros-$noise';
}
