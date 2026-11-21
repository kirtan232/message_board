import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/board_service.dart';

/// Asks for the new text of a message. Returns the text, or null if
/// cancelled or unchanged.
Future<String?> showEditMessageDialog(BuildContext context, Message message) {
  return showDialog<String>(
    context: context,
    builder: (_) => _EditMessageDialog(initialText: message.text),
  );
}

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final text = _controller.text.trim();
    Navigator.pop(context, text == widget.initialText.trim() ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit message'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: kMaxMessageLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          validator: (v) => BoardService.validateText(v ?? ''),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Confirms a delete. Returns true only if the user tapped Delete.
Future<bool> confirmDeleteMessage(BuildContext context) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete message?'),
      content: const Text('This removes it from the board for everyone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
