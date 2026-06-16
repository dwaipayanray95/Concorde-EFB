import 'package:flutter/material.dart';
import '../core/ui_tokens.dart';

class EfbTextField extends StatefulWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? placeholder;
  final bool readOnly;

  const EfbTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.placeholder,
    this.readOnly = false,
  });

  @override
  State<EfbTextField> createState() => _EfbTextFieldState();
}

class _EfbTextFieldState extends State<EfbTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(EfbTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller only if external value changed significantly
    if (widget.initialValue != oldWidget.initialValue && 
        widget.initialValue != _controller.text) {
      
      // For numeric fields, ignore trivial formatting differences like "10." vs "10.0"
      if (widget.keyboardType == TextInputType.number) {
        final currentVal = double.tryParse(_controller.text);
        final newVal = double.tryParse(widget.initialValue);
        if (currentVal != null && newVal != null && currentVal == newVal) {
          // If the values are numerically identical, don't update to avoid cursor jump
          return;
        }
      }
      
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 11, color: UiTokens.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          readOnly: widget.readOnly,
          style: const TextStyle(color: UiTokens.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: const TextStyle(color: UiTokens.textDim),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: UiTokens.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}
