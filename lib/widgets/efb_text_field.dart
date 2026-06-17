import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/ui_tokens.dart';
import 'efb_glass_container.dart';

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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: UiTokens.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        EfbGlassContainer(
          blur: 10,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            readOnly: widget.readOnly,
            style: GoogleFonts.jetBrainsMono(
              color: UiTokens.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: GoogleFonts.plusJakartaSans(color: UiTokens.textDim),
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
