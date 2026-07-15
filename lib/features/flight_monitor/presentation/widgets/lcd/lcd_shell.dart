import 'package:flutter/material.dart';
import 'lcd_theme.dart';

/// Shared bordered/glowing shell with a title + tag header, used by every
/// LCD panel module.
class LcdModulePanel extends StatelessWidget {
  final String title;
  final String tag;
  final Color tagColor;
  final Widget child;

  const LcdModulePanel({
    super.key,
    required this.title,
    required this.tag,
    required this.child,
    this.tagColor = lcdAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: lcdPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lcdBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: lcdAccent.withValues(alpha: 0.08), blurRadius: 18, spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: lcdLabel(size: 9, color: lcdAccent),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tagColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(tag, style: lcdMono(size: 7, color: tagColor)),
                ),
              ],
            ),
          ),
          Divider(color: lcdBorder, height: 14, thickness: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

Widget lcdBigCell(String label, String val, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: lcdCard,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: lcdBorder, width: 1.5),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10)],
    ),
    child: Column(
      children: [
        Text(label, style: lcdLabel(size: 9)),
        const SizedBox(height: 4),
        Text(val, style: lcdMono(size: 22, color: color)),
      ],
    ),
  );
}

Widget lcdInfoCell(String label, String val, [Color valColor = Colors.white]) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: lcdCard,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: lcdBorder),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: lcdLabel(size: 8),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              val,
              style: lcdMono(size: 10, color: valColor),
            ),
          ),
        ),
      ],
    ),
  );
}
