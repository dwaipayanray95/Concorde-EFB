import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'fm_theme.dart';

/// Top status/controls bar: connection dot + Zulu clock, playback-log
/// button, and record button.
class FmToolbar extends StatelessWidget {
  final bool isConnected;
  final bool isRecording;
  final int recordedFramesCount;
  final TelemetryModel telemetry;
  final VoidCallback onToggleRecording;

  const FmToolbar({
    super.key,
    required this.isConnected,
    required this.isRecording,
    required this.recordedFramesCount,
    required this.telemetry,
    required this.onToggleRecording,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected ? fmGreen : fmRed;
    final statusLabel = isConnected ? 'SIMCONNECT BRIDGE CONNECTED' : 'DISCONNECTED';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.6), blurRadius: 10)],
              ),
            ),
            const SizedBox(width: 12),
            Text(statusLabel, style: fmLabel(size: 12, color: statusColor, weight: FontWeight.w800, letterSpacing: 1.4)),
            const SizedBox(width: 8),
            Container(width: 1, height: 16, color: fmBorder, margin: const EdgeInsets.symmetric(horizontal: 4)),
            Text('${telemetry.zuluTime}Z', style: fmMono(size: 12, color: fmMuted)),
          ],
        ),
        if (isConnected)
          _RecordButton(
            recording: isRecording,
            frameCount: recordedFramesCount,
            onPressed: onToggleRecording,
          ),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool recording;
  final int frameCount;
  final VoidCallback onPressed;
  const _RecordButton({required this.recording, required this.frameCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = recording ? fmRed : fmTextFaint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: recording ? fmRedDeep : const Color(0xFF1E293B)),
            color: recording ? fmRedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: recording ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: recording ? BorderRadius.circular(2) : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                recording ? 'STOP ($frameCount)' : 'RECORD',
                style: fmLabel(size: 12, color: color, weight: FontWeight.w800, letterSpacing: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
