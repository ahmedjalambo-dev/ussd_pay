/// A recipient type is whatever key a wallet declares under `templates` in
/// `assets/wallets.json`.
///
/// It is deliberately **not** an enum: adding a third type to a wallet's JSON
/// must not require a Dart change. These constants exist only so the common two
/// can be given icons and translated labels; an unrecognised key still renders,
/// falling back to the raw key as its label.
abstract final class RecipientTypes {
  static const String friend = 'friend';
  static const String merchant = 'merchant';

  /// Types the UI has a translated label and icon for.
  static const Set<String> known = {friend, merchant};
}
