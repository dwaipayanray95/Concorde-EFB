import 'package:flutter/material.dart';
import 'lcd_theme.dart';

class LcdAlert {
  final String text;
  final Color color;
  const LcdAlert(this.text, this.color);
}

class LcdAlertBar extends StatefulWidget {
  final List<LcdAlert> alerts;
  final bool isConnected;
  final String zuluTime;

  const LcdAlertBar({super.key, required this.alerts, required this.isConnected, required this.zuluTime});

  @override
  State<LcdAlertBar> createState() => _LcdAlertBarState();
}

class _LcdAlertBarState extends State<LcdAlertBar> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasWarning = widget.alerts.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: hasWarning
            ? Colors.red.withValues(alpha: 0.06)
            : Colors.green.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: hasWarning ? lcdRed.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Status dot (pulsing when warning)
          if (hasWarning)
            AnimatedBuilder(
              animation: _pulse,
              builder: (ctx, child) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: lcdRed.withValues(alpha: _pulse.value),
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),

          // Label
          Text(
            hasWarning ? 'MASTER CAUTION:' : 'SYSTEMS NOMINAL',
            style: lcdMono(
              size: 10,
              color: hasWarning ? lcdRed : Colors.greenAccent,
            ),
          ),

          if (hasWarning) ...[
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.alerts.map((a) => _badge(a.text, a.color)).toList(),
                ),
              ),
            ),
          ] else
            const Expanded(child: SizedBox()),

          // Zulu time
          Text(
            'Z ${widget.zuluTime}',
            style: lcdMono(size: 10, color: lcdMuted),
          ),

          const SizedBox(width: 12),

          // SimConnect indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (widget.isConnected ? Colors.greenAccent : Colors.blueAccent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: (widget.isConnected ? Colors.greenAccent : Colors.blueAccent).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              widget.isConnected ? 'SIMCONNECT LIVE' : 'STANDBY',
              style: lcdMono(
                size: 8,
                color: widget.isConnected ? Colors.greenAccent : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: lcdMono(size: 8, color: color)),
    );
  }
}
