import 'package:flutter/material.dart';

class RenameDialog extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onConfirm;

  const RenameDialog({
    super.key,
    required this.initialName,
    required this.onConfirm,
  });

  @override
  State<RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'File name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        maxLength: 50,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.onConfirm(name);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
