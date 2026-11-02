import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// Asks for the name to save a recipient under.
///
/// Pops with the trimmed name, or `null` if the user cancelled.
///
/// This is a widget rather than an inline `AlertDialog` for one specific
/// reason: it owns its [TextEditingController] and disposes it in its own
/// [State.dispose]. The previous inline version disposed the controller
/// immediately after `await showDialog(...)`, but that future completes the
/// moment `Navigator.pop` runs -- while the route is still animating out and
/// the field is still mounted and listening. The field then touched a disposed
/// controller and the screen threw.
class SaveFavoriteDialog extends StatefulWidget {
  const SaveFavoriteDialog({super.key, this.initialName});

  /// Pre-filled name, when the number already came from a contact or favorite.
  final String? initialName;

  @override
  State<SaveFavoriteDialog> createState() => _SaveFavoriteDialogState();
}

class _SaveFavoriteDialogState extends State<SaveFavoriteDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    // Guarded rather than assumed: [_submit] also runs from the keyboard's
    // done key, which does not respect the button's disabled state.
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.saveAsFavorite),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _submit(),
        // Redraws so the Save button's enabled state tracks the field.
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: l10n.favoriteNameLabel,
          prefixIcon: const Icon(Icons.person_outline),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
          // Disabled rather than silently doing nothing: the old version
          // accepted the tap, closed, and saved nothing.
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
