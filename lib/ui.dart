import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Small helpers shared by the screens.

/// Turns a backend error into a sentence a user can act on.
String errorText(Object e) {
  if (e is PostgrestException) {
    return switch (e.code) {
      '23505' => 'That is already taken (for example, the bed is occupied).',
      '23503' => 'It is still in use, so it can\'t be removed.',
      '42501' => 'You don\'t have permission to do that.',
      _ => e.message,
    };
  }
  return e.toString().replaceFirst('Exception: ', '');
}

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Runs an action and shows [done] or the error. Returns true on success.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action,
  String done,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    return false;
  }
}

/// Asks for one line of text. Returns null if cancelled or empty.
Future<String?> askText(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
  bool number = false,
}) async {
  final text = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: text,
        autofocus: true,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return (result == null || result.trim().isEmpty) ? null : result.trim();
}

Future<bool> confirm(BuildContext context, String question, String yes) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(question),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return ok == true;
}
