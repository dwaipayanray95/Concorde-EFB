import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';

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
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      if (widget.keyboardType == TextInputType.number) {
        final currentVal = double.tryParse(_controller.text);
        final newVal = double.tryParse(widget.initialValue);
        if (currentVal != null && newVal != null && currentVal == newVal) {
          return;
        }
      }

      final selection = _controller.selection;
      _controller.text = widget.initialValue;
      try {
        _controller.selection = selection;
      } catch (_) {
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: uiText(
            context,
            color: colors.textSecondary,
            size: 11,
            weight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.dividerStrong, width: 1.5),
          ),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            readOnly: widget.readOnly,
            style: uiText(
              context,
              color: colors.textPrimary,
              weight: FontWeight.bold,
              size: 15,
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: uiText(context, color: colors.textDim, size: 15),
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
