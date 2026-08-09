import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// A recipient chosen from the device address book.
class PickedContact {
  const PickedContact({required this.number, this.name});

  final String number;
  final String? name;
}

/// Why a contact pick produced nothing.
enum ContactPickFailure {
  /// The user backed out of the picker.
  cancelled,

  /// READ_CONTACTS was refused. Typing the number by hand still works.
  permissionDenied,

  /// The chosen contact has no phone number on it.
  noPhoneNumber,
}

class ContactPickResult {
  const ContactPickResult.picked(PickedContact this.contact) : failure = null;
  const ContactPickResult.failed(ContactPickFailure this.failure)
      : contact = null;

  final PickedContact? contact;
  final ContactPickFailure? failure;
}

/// Wraps the native contact picker.
///
/// This is the app's only permission. It is requested at the moment the user
/// taps "Contacts", never at startup, and refusing it costs nothing: the phone
/// field still accepts a typed number.
abstract final class ContactPickerService {
  static Future<ContactPickResult> pick() async {
    // The picker itself is permissionless, but returns only id and displayName
    // without READ_CONTACTS -- and a name without a number is useless here.
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    if (!granted) {
      return const ContactPickResult.failed(ContactPickFailure.permissionDenied);
    }

    final Contact? contact;
    try {
      contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
    } on PlatformException {
      return const ContactPickResult.failed(ContactPickFailure.permissionDenied);
    }

    if (contact == null) {
      return const ContactPickResult.failed(ContactPickFailure.cancelled);
    }
    if (contact.phones.isEmpty) {
      return const ContactPickResult.failed(ContactPickFailure.noPhoneNumber);
    }

    // The raw number goes straight to PhoneNormalizer, which handles the
    // country codes, spaces, and RTL marks that contact entries are full of.
    return ContactPickResult.picked(
      PickedContact(
        number: contact.phones.first.number,
        name: contact.displayName,
      ),
    );
  }
}
