import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/formatters.dart';
import '../../../../core/ui_text.dart';
import '../../data/flight_log.dart';

enum ProfileMode { altMach, speeds, fuel, cg }

/// Interactive dual-axis flight profile telemetry canvas with scrub cursor,
/// altitude gradient fill, Mach/Speed/Fuel/CG curve, milestone flags, and live readout bar.
class FlightProfileChart extends StatefulWidget {
  final FlightLog log;

  const FlightProfileChart({super.key, required this.log});

  @override
  State<FlightProfileChart> createState() => _FlightProfileChartState();
}

class _FlightProfileChartState extends State<FlightProfileChart> {
  ProfileMode _mode = ProfileMode.altMach;
  double? _scrubFrac;
  late List<double> _fuelCurve;

  @override
  void initState() {
    super.initState();
    _fuelCurve = _computeFuelCurve();
  }

  @override
  void didUpdateWidget(covariant FlightProfileChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log != widget.log) {
      _fuelCurve = _computeFuelCurve();
    }
  }

  /// Calculates the fuel profile across the flight track.
  /// If track points contain real-time recorded fuel (p[8] > 0), it uses them.
  /// Otherwise, it performs a realistic physics-based burn rate integration
  /// (takeoff/transonic reheat = 60-65 t/h, cruise = 19 t/h, idle descent = 8.5 t/h)
  /// calibrated to the flight's recorded fuelTakeoffKg and fuelLandingKg so the curve
  /// reflects real aerodynamic fuel consumption instead of a flat linear line.
  List<double> _computeFuelCurve() {
    final track = widget.log.track;
    if (track.isEmpty) return const [];

    // Check if track points have recorded fuel (p.length > 8 && p[8] > 0)
    final hasRealFuel = track.any((p) => p.length > 8 && p[8] > 0);
    if (hasRealFuel) {
      return track.map((p) => p.length > 8 ? p[8].toDouble() : 0.0).toList();
    }

    // Fallback: Phase-aware physics burn rate integration
    final startF = widget.log.fuelTakeoffKg ?? widget.log.fuelBlockOutKg ?? 0.0;
    final endF = widget.log.fuelLandingKg ??
        widget.log.fuelBlockInKg ??
        (startF > 0 ? startF * 0.25 : 0.0);

    if (startF <= 0 || track.length < 2) {
      return List<double>.filled(track.length, startF);
    }

    final totalBurn = startF - endF;
    if (totalBurn <= 0) {
      return List<double>.filled(track.length, startF);
    }

    final intervalBurns = <double>[];
    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final gs = p.length > 4 ? p[4].toDouble() : 0.0;
      final m = _getMach(i);
      final vs = _getVs(i);

      final dt = i > 0
          ? math.max(1.0, (p[0] - track[i - 1][0]).toDouble())
          : 5.0;

      // Concorde fuel flow rate in kg/s across flight regimes
      double rateKgPerSec;
      if (alt < 1000 && gs < 60) {
        rateKgPerSec = 1500 / 3600.0; // Taxi idle (~1.5 t/h)
      } else if (alt < 3000 && vs > 1000) {
        rateKgPerSec = 65000 / 3600.0; // Takeoff reheat (~65 t/h)
      } else if (alt >= 28000 && alt < 50000 && (m >= 0.95 || vs > 800)) {
        rateKgPerSec = 60000 / 3600.0; // Transonic reheat (~60 t/h)
      } else if (alt < 28000 && vs > 500) {
        rateKgPerSec = 26000 / 3600.0; // Subsonic climb (~26 t/h)
      } else if (alt >= 45000 && vs > -400) {
        rateKgPerSec = 19000 / 3600.0; // Supercruise (~19 t/h)
      } else if (vs < -800) {
        rateKgPerSec = 8500 / 3600.0; // Idle descent (~8.5 t/h)
      } else {
        rateKgPerSec = 14000 / 3600.0; // Approach / enroute (~14 t/h)
      }

      intervalBurns.add(rateKgPerSec * dt);
    }

    final totalSimBurn = intervalBurns.fold(0.0, (s, b) => s + b);
    if (totalSimBurn <= 0) {
      return List<double>.filled(track.length, startF);
    }

    var cumBurn = 0.0;
    final curve = <double>[];
    for (var i = 0; i < track.length; i++) {
      cumBurn += intervalBurns[i];
      final frac = (cumBurn / totalSimBurn).clamp(0.0, 1.0);
      curve.add(startF - totalBurn * frac);
    }

    return curve;
  }

  double _getMach(int idx) {
    final track = widget.log.track;
    if (idx < 0 || idx >= track.length) return 0.0;
    final p = track[idx];
    if (p.length > 7 && p[7].toDouble() > 0) return p[7].toDouble();

    final alt = p.length > 3 ? p[3].toDouble() : 0.0;
    final gs = p.length > 4 ? p[4].toDouble() : 0.0;
    if (gs <= 0) return 0.0;

    // Local speed of sound in knots vs altitude
    final soundSpeedKt = alt >= 36089
        ? 573.0
        : 661.0 - (alt / 36089.0) * (661.0 - 573.0);

    final m = gs / soundSpeedKt;
    if (widget.log.maxMach > 0 && m > widget.log.maxMach * 1.05) {
      return widget.log.maxMach;
    }
    return m;
  }

  double _getVs(int idx) {
    final track = widget.log.track;
    if (idx < 0 || idx >= track.length) return 0.0;
    final p = track[idx];
    if (p.length > 6 && p[6].toDouble() != 0) return p[6].toDouble();

    if (idx == 0) {
      if (track.length > 1) {
        final dt = math.max(1.0, (track[1][0] - p[0]).toDouble());
        return (track[1][3].toDouble() - p[3].toDouble()) / dt * 60.0;
      }
      return 0.0;
    }
    final prev = track[idx - 1];
    final dt = math.max(1.0, (p[0] - prev[0]).toDouble());
    return (p[3].toDouble() - prev[3].toDouble()) / dt * 60.0;
  }

  double _getIas(int idx) {
    final track = widget.log.track;
    if (idx < 0 || idx >= track.length) return 0.0;
    final p = track[idx];
    if (p.length > 5 && p[5].toDouble() > 0) return p[5].toDouble();

    final alt = p.length > 3 ? p[3].toDouble() : 0.0;
    final gs = p.length > 4 ? p[4].toDouble() : 0.0;
    if (gs <= 0) return 0.0;

    // ISA density ratio sqrt(rho / rho0)
    final sigma = alt <= 0
        ? 1.0
        : (alt >= 36089
            ? 0.53 * math.exp(-(alt - 36089) / 48000.0)
            : math.pow(math.max(0.01, 1.0 - 6.875e-6 * alt), 2.128).toDouble());

    return (gs * sigma).clamp(0.0, 530.0);
  }

  bool _isReheatActive(int idx) {
    final track = widget.log.track;
    if (idx < 0 || idx >= track.length) return false;
    final p = track[idx];
    final alt = p.length > 3 ? p[3].toDouble() : 0.0;
    final gs = p.length > 4 ? p[4].toDouble() : 0.0;
    final m = _getMach(idx);
    final vs = _getVs(idx);

    // 1. Takeoff Reheat: active during ground roll & initial climb (~90s or up to 3500ft)
    if (widget.log.reheatSec > 0 && widget.log.takeoff != null) {
      final epoch = p[0].toInt();
      final toEpoch = widget.log.takeoff!.millisecondsSinceEpoch ~/ 1000;
      final reheatEnd = toEpoch + widget.log.reheatSec.round();
      if (epoch >= toEpoch && epoch <= reheatEnd && alt < 4000) {
        return true;
      }
    } else if (alt < 2500 && gs >= 60 && vs > 200 && idx < track.length * 0.25) {
      return true;
    }

    // 2. Transonic Acceleration Reheat: FL280 to FL500 accelerating through M0.95 to M1.70
    if (alt >= 26000 && alt <= 50000 && m >= 0.95 && m <= 1.70 && vs > 100) {
      return true;
    }

    return false;
  }

  double _getCg(int idx) {
    final track = widget.log.track;
    if (idx < 0 || idx >= track.length) return 0.0;
    final p = track[idx];
    final cg = p.length > 9 ? p[9].toDouble() : 0.0;
    if (cg > 0) return cg;

    final m = _getMach(idx);
    final vs = _getVs(idx);
    final isDescent = idx > track.length * 0.7 || vs < -1000;

    if (m <= 0.93) return 53.5;
    if (m >= 1.70 && !isDescent) return 59.0;
    final frac = ((m - 0.93) / (1.70 - 0.93)).clamp(0.0, 1.0);
    return 53.5 + 5.5 * frac;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = widget.log.track;

    if (track.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            'No 5-second telemetry track recorded for this flight.',
            style: uiText(context, size: 12, color: colors.textSecondary),
          ),
        ),
      );
    }

    final pointCount = track.length;
    final selectedIdx = _scrubFrac == null
        ? (pointCount * 0.45).round().clamp(0, pointCount - 1)
        : (_scrubFrac! * (pointCount - 1)).round().clamp(0, pointCount - 1);
    final p = track[selectedIdx];

    // Decode point with reconstructed flight kinematics
    final altFt = p.length > 3 ? p[3].toDouble() : 0.0;
    final gsKt = p.length > 4 ? p[4].toDouble() : 0.0;
    final iasKt = _getIas(selectedIdx);
    final vsFpm = _getVs(selectedIdx);
    final mach = _getMach(selectedIdx);
    final fuelKg = selectedIdx < _fuelCurve.length ? _fuelCurve[selectedIdx] : 0.0;
    final cgPct = _getCg(selectedIdx);
    final isReheat = _isReheatActive(selectedIdx);

    // Elapsed time calculation
    final firstEpoch = track.first[0].toInt();
    final curEpoch = p[0].toInt();
    final elapsedSec = math.max(0, curEpoch - firstEpoch);
    final elapsedH = elapsedSec ~/ 3600;
    final elapsedM = (elapsedSec % 3600) ~/ 60;
    final elapsedStr =
        '+${elapsedH.toString().padLeft(2, '0')}:${elapsedM.toString().padLeft(2, '0')}';

    final zuluDt = DateTime.fromMillisecondsSinceEpoch(curEpoch * 1000, isUtc: true);
    final zuluStr =
        '${zuluDt.hour.toString().padLeft(2, '0')}:${zuluDt.minute.toString().padLeft(2, '0')}:${zuluDt.second.toString().padLeft(2, '0')}Z';

    // Phase inference
    String phase;
    if (altFt < 1000 && gsKt < 80) {
      phase = 'TAXI / GROUND';
    } else if (isReheat && altFt < 5000) {
      phase = 'TAKEOFF REHEAT';
    } else if (altFt < 28000 && mach < 0.95 && vsFpm > 500) {
      phase = 'SUBSONIC CLIMB';
    } else if (isReheat) {
      phase = 'TRANSONIC REHEAT';
    } else if (altFt >= 45000 && mach >= 1.70 && vsFpm > -500) {
      phase = mach >= 2.0 ? 'M2.0 SUPERCRUISE' : 'SUPERCRUISE';
    } else if (vsFpm < -1000) {
      phase = 'DECEL & DESCENT';
    } else {
      phase = 'APPROACH / ENROUTE';
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Layer Switcher
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 750;

              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MISSION PROFILE & TELEMETRY RECORDER',
                        style: uiText(
                          context,
                          size: 11,
                          weight: FontWeight.w900,
                          color: colors.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sampled at 5s interval (${track.length} points) · Drag or hover to inspect live point',
                    style: uiText(context, size: 10, color: colors.textSecondary),
                  ),
                ],
              );

              final modeButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SECONDARY OVERLAY:',
                    style: uiText(
                      context,
                      size: 9,
                      weight: FontWeight.w800,
                      color: colors.textDim,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors.resultsBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.dividerStrong.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modeBtn('MACH', ProfileMode.altMach, colors),
                        _modeBtn('AIRSPEED', ProfileMode.speeds, colors),
                        _modeBtn('FUEL ON BOARD', ProfileMode.fuel, colors),
                        _modeBtn('CG % MAC', ProfileMode.cg, colors),
                      ],
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    modeButtons,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: modeButtons,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Synchronized Live Telemetry Readout Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.resultsBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.dividerStrong.withValues(alpha: 0.5),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;

                Widget cell(String label, String value, [Color? valColor]) =>
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: uiText(
                            context,
                            size: 8,
                            weight: FontWeight.w800,
                            color: colors.textDim,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: uiText(
                            context,
                            size: 13,
                            weight: FontWeight.w900,
                            color: valColor ?? colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );

                final phaseBadge = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FLIGHT PHASE',
                      style: uiText(
                        context,
                        size: 8,
                        weight: FontWeight.w800,
                        color: colors.textDim,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isReheat
                                ? colors.error
                                : (mach >= 1.0 ? colors.accent : colors.surface))
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isReheat
                                  ? colors.error
                                  : (mach >= 1.0
                                      ? colors.accent
                                      : colors.dividerStrong))
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        phase,
                        style: uiText(
                          context,
                          size: 10,
                          weight: FontWeight.w900,
                          color: isReheat
                              ? colors.error
                              : (mach >= 1.0 ? colors.accent : colors.textPrimary),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                if (wide) {
                  return Column(
                    children: [
                      // Row 1: Kinematics & Nav
                      Row(
                        children: [
                          Expanded(
                            child: cell('TIME (ZULU / ETE)', '$zuluStr ($elapsedStr)'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'ALTITUDE',
                              'FL${(altFt / 100).round()} (${numFormat.format(altFt.round())} FT)',
                              colors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'MACH NUMBER',
                              'M${mach.toStringAsFixed(2)}',
                              mach >= 1.0 ? colors.accent : const Color(0xFF06B6D4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'AIRSPEED',
                              '${iasKt.round()} KT IAS · ${gsKt.round()} KT GS',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 1,
                        color: colors.dividerStrong.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 10),
                      // Row 2: Aerodynamics & Systems
                      Row(
                        children: [
                          Expanded(
                            child: cell(
                              'VERTICAL SPEED',
                              '${vsFpm >= 0 ? '+' : ''}${vsFpm.round()} FPM',
                              vsFpm > 500
                                  ? colors.success
                                  : (vsFpm < -500 ? colors.mvfr : colors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: phaseBadge),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'FUEL ON BOARD',
                              fuelKg > 0 ? '${numFormat.format(fuelKg.round())} KG' : '--',
                              const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'CG POSITION',
                              cgPct > 0 ? '${cgPct.toStringAsFixed(1)}% MAC' : '--',
                              cgPct >= 52.0 && cgPct <= 59.3 ? colors.success : colors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: cell(
                              'PROPULSION',
                              isReheat ? 'REHEAT (4×)' : 'DRY THRUST',
                              isReheat ? colors.error : colors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      cell('TIME', '$zuluStr ($elapsedStr)'),
                      cell('ALTITUDE', 'FL${(altFt / 100).round()}', colors.accent),
                      cell('MACH', 'M${mach.toStringAsFixed(2)}', colors.accent),
                      cell('IAS / GS', '${iasKt.round()} / ${gsKt.round()} KT'),
                      cell('VS', '${vsFpm.round()} FPM'),
                      cell(
                        'FUEL',
                        fuelKg > 0 ? '${numFormat.format(fuelKg.round())} KG' : '--',
                      ),
                      cell(
                        'CG',
                        cgPct > 0 ? '${cgPct.toStringAsFixed(1)}%' : '--',
                      ),
                      cell(
                        'PROPULSION',
                        isReheat ? 'REHEAT (4×)' : 'DRY',
                        isReheat ? colors.error : colors.textDim,
                      ),
                      phaseBadge,
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Flight Profile Canvas
          LayoutBuilder(
            builder: (context, c) {
              final chartWidth = c.maxWidth;
              return RepaintBoundary(
                child: GestureDetector(
                  onHorizontalDragStart: (d) =>
                      _handleScrub(d.localPosition.dx, chartWidth),
                  onHorizontalDragUpdate: (d) =>
                      _handleScrub(d.localPosition.dx, chartWidth),
                  onTapDown: (d) => _handleScrub(d.localPosition.dx, chartWidth),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    onHover: (e) => _handleScrub(e.localPosition.dx, chartWidth),
                    child: SizedBox(
                      width: double.infinity,
                      height: 250,
                      child: CustomPaint(
                        painter: _ProfileChartPainter(
                          track: track,
                          colors: colors,
                          mode: _mode,
                          scrubFrac: _scrubFrac ?? 0.45,
                          fuelCurve: _fuelCurve,
                          machFn: _getMach,
                          iasFn: _getIas,
                          vsFn: _getVs,
                          reheatFn: _isReheatActive,
                          cgFn: _getCg,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Chart Legends
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _legendItem('ALTITUDE (FL0–600)', colors.accent),
                  if (_mode == ProfileMode.altMach)
                    _legendItem('MACH (M0.0–2.2)', const Color(0xFF06B6D4)),
                  if (_mode == ProfileMode.speeds)
                    _legendItem('INDICATED AIRSPEED (IAS KT)', const Color(0xFF06B6D4)),
                  if (_mode == ProfileMode.fuel)
                    _legendItem('FUEL ON BOARD (AUTO-SCALED)', const Color(0xFF06B6D4)),
                  if (_mode == ProfileMode.cg) ...[
                    _legendItem('CG % MAC (52–60%)', const Color(0xFF10B981)),
                    _legendItem(
                      'ENVELOPE CORRIDOR (52.5–59.1%)',
                      colors.success.withValues(alpha: 0.6),
                      isDot: true,
                    ),
                  ],
                  _legendItem(
                    'SUPERCRUISE CORRIDOR (FL500–600)',
                    colors.accent.withValues(alpha: 0.6),
                    isDot: true,
                  ),
                  _legendItem('REHEAT ACTIVE (4×)', colors.error, isDot: true),
                ],
              ),
              Text(
                '* Scrub across chart to inspect live flight parameters',
                style: uiText(context, size: 9, color: colors.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleScrub(double localX, double totalW) {
    const padL = 44.0;
    const padR = 44.0;
    final plotW = totalW - padL - padR;
    final frac = ((localX - padL) / plotW).clamp(0.0, 1.0);
    setState(() => _scrubFrac = frac);
  }

  Widget _modeBtn(String label, ProfileMode m, AppColors colors) {
    final active = _mode == m;
    return Material(
      color: active ? colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => setState(() => _mode = m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w900,
              color: active ? AppColors.dark.bg : colors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, {bool isDot = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDot
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                )
              : Container(
                  width: 10,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
          const SizedBox(width: 5),
          Text(
            label,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
}

class _ProfileChartPainter extends CustomPainter {
  final List<List<num>> track;
  final AppColors colors;
  final ProfileMode mode;
  final double scrubFrac;
  final List<double> fuelCurve;
  final double Function(int idx) machFn;
  final double Function(int idx) iasFn;
  final double Function(int idx) vsFn;
  final bool Function(int idx) reheatFn;
  final double Function(int idx) cgFn;

  _ProfileChartPainter({
    required this.track,
    required this.colors,
    required this.mode,
    required this.scrubFrac,
    required this.fuelCurve,
    required this.machFn,
    required this.iasFn,
    required this.vsFn,
    required this.reheatFn,
    required this.cgFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 44.0;
    const padR = 44.0;
    const padT = 20.0;
    const padB = 24.0;

    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (track.length < 2 || plotW <= 0 || plotH <= 0) return;

    // Grid lines & Y-Axis Labels
    final gridPaint = Paint()
      ..color = colors.dividerStrong.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dynamic auto-range for fuel Y-axis
    double fuelAxisMin = 0.0;
    double fuelAxisMax = 96000.0;

    if (mode == ProfileMode.fuel && fuelCurve.isNotEmpty) {
      var minF = double.infinity;
      var maxF = 0.0;
      for (final f in fuelCurve) {
        if (f > maxF) maxF = f;
        if (f > 0 && f < minF) minF = f;
      }
      if (minF == double.infinity) minF = 0.0;
      if (maxF <= 0) maxF = 96000.0;

      final span = maxF - minF;
      if (span > 0) {
        final step = span < 15000 ? 5000.0 : 10000.0;
        fuelAxisMax = (maxF / step).ceil() * step;
        fuelAxisMin = math.max(0.0, (minF / step).floor() * step);
        if (fuelAxisMax <= fuelAxisMin) {
          fuelAxisMax = minF + step;
          fuelAxisMin = math.max(0.0, minF - step);
        }
      }
    }

    // Dynamic scale for speeds Y-axis
    double speedAxisMax = 600.0;
    if (mode == ProfileMode.speeds) {
      var maxIas = 0.0;
      for (var i = 0; i < track.length; i++) {
        final s = iasFn(i);
        if (s > maxIas) maxIas = s;
      }
      speedAxisMax = maxIas > 450.0 ? 600.0 : math.max(300.0, ((maxIas / 100).ceil() * 100.0));
    }

    for (var i = 0; i <= 4; i++) {
      final y = padT + (plotH / 4) * i;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);

      // Left labels: Altitude (FL600 -> FL0)
      final fl = 600 - i * 150;
      final tpL = TextPainter(
        text: TextSpan(
          text: 'FL$fl',
          style: TextStyle(
            color: colors.textDim,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpL.paint(canvas, Offset(padL - tpL.width - 6, y - tpL.height / 2));

      // Right labels: Mach or Speeds or Fuel or CG
      String rText;
      Color rColor = const Color(0xFF06B6D4);
      switch (mode) {
        case ProfileMode.altMach:
          final mVal = (2.2 - i * (2.2 / 4)).toStringAsFixed(1);
          rText = 'M$mVal';
        case ProfileMode.speeds:
          final sVal = (speedAxisMax - (speedAxisMax * i / 4.0)).round();
          rText = '$sVal KT';
        case ProfileMode.fuel:
          final fVal = fuelAxisMax - (fuelAxisMax - fuelAxisMin) * (i / 4.0);
          final fTonnes = fVal / 1000.0;
          rText = '${fTonnes.toStringAsFixed(1)}T';
        case ProfileMode.cg:
          final cgVal = (60.0 - i * 2.0).toStringAsFixed(1);
          rText = '$cgVal%';
          rColor = const Color(0xFF10B981);
      }

      final tpR = TextPainter(
        text: TextSpan(
          text: rText,
          style: TextStyle(
            color: rColor,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpR.paint(canvas, Offset(size.width - padR + 6, y - tpR.height / 2));
    }

    // Concorde FL500-FL600 Supercruise corridor tint
    final yFL500 = padT + plotH * (1.0 - (50000 / 60000));
    final supercruiseRect = Rect.fromLTWH(padL, padT, plotW, yFL500 - padT);
    canvas.drawRect(
      supercruiseRect,
      Paint()..color = colors.accent.withValues(alpha: 0.04),
    );

    // If CG mode: draw CG certified envelope limits background
    if (mode == ProfileMode.cg) {
      final y591 = padT + plotH * (1.0 - ((59.1 - 52.0) / 8.0).clamp(0.0, 1.0));
      final y525 = padT + plotH * (1.0 - ((52.5 - 52.0) / 8.0).clamp(0.0, 1.0));
      canvas.drawRect(
        Rect.fromLTRB(padL, y591, padL + plotW, y525),
        Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.06),
      );
    }

    double getX(int idx) => padL + (idx / (track.length - 1)) * plotW;

    // Reheat Highlight Spans (takeoff reheat & transonic climb)
    var inReheat = false;
    var reheatStart = 0;
    for (var i = 0; i < track.length; i++) {
      final active = reheatFn(i);

      if (active && !inReheat) {
        inReheat = true;
        reheatStart = i;
      } else if (!active && inReheat) {
        inReheat = false;
        final x1 = getX(reheatStart);
        final x2 = getX(i);
        canvas.drawRect(
          Rect.fromLTWH(x1, padT, math.max(3.0, x2 - x1), plotH),
          Paint()..color = colors.error.withValues(alpha: 0.16),
        );
      }
    }
    if (inReheat) {
      final x1 = getX(reheatStart);
      final x2 = getX(track.length - 1);
      canvas.drawRect(
        Rect.fromLTWH(x1, padT, math.max(3.0, x2 - x1), plotH),
        Paint()..color = colors.error.withValues(alpha: 0.16),
      );
    }

    // Curve 1: Altitude Profile (Amber)
    final altPath = Path();
    final altFill = Path();
    var first = true;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final x = getX(i);
      final y = padT + plotH * (1.0 - (alt / 60000).clamp(0.0, 1.0));

      if (first) {
        altPath.moveTo(x, y);
        altFill.moveTo(x, padT + plotH);
        altFill.lineTo(x, y);
        first = false;
      } else {
        altPath.lineTo(x, y);
        altFill.lineTo(x, y);
      }
    }

    altFill.lineTo(padL + plotW, padT + plotH);
    altFill.close();

    // Fill underneath altitude
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.accent.withValues(alpha: 0.25),
          colors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, padT, size.width, plotH));
    canvas.drawPath(altFill, fillPaint);

    final altPaint = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(altPath, altPaint);

    // Curve 2: Secondary Data (Mach or Speeds or Fuel or CG)
    final secPath = Path();
    first = true;

    for (var i = 0; i < track.length; i++) {
      final x = getX(i);
      double normVal;

      switch (mode) {
        case ProfileMode.altMach:
          final m = machFn(i);
          normVal = (m / 2.2).clamp(0.0, 1.0);
        case ProfileMode.speeds:
          final ias = iasFn(i);
          normVal = (ias / speedAxisMax).clamp(0.0, 1.0);
        case ProfileMode.fuel:
          final f = i < fuelCurve.length ? fuelCurve[i] : 0.0;
          normVal = ((f - fuelAxisMin) /
                  math.max(1.0, fuelAxisMax - fuelAxisMin))
              .clamp(0.0, 1.0);
        case ProfileMode.cg:
          final cg = cgFn(i);
          normVal = ((cg - 52.0) / 8.0).clamp(0.0, 1.0);
      }

      final y = padT + plotH * (1.0 - normVal);
      if (first) {
        secPath.moveTo(x, y);
        first = false;
      } else {
        secPath.lineTo(x, y);
      }
    }

    final secPaint = Paint()
      ..color = mode == ProfileMode.cg
          ? const Color(0xFF10B981)
          : const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(secPath, secPaint);

    // Milestone Event Flags
    _drawMilestones(canvas, padL, plotW, padT, plotH);

    // Crosshair Scrubber Cursor
    final scrubX = padL + scrubFrac * plotW;
    final scrubPaint = Paint()
      ..color = colors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(scrubX, padT), Offset(scrubX, padT + plotH), scrubPaint);

    final curIdx =
        (scrubFrac * (track.length - 1)).round().clamp(0, track.length - 1);
    final curAlt =
        track[curIdx].length > 3 ? track[curIdx][3].toDouble() : 0.0;
    final dotY = padT + plotH * (1.0 - (curAlt / 60000).clamp(0.0, 1.0));

    canvas.drawCircle(Offset(scrubX, dotY), 4.5, Paint()..color = colors.textPrimary);
    canvas.drawCircle(Offset(scrubX, dotY), 3.0, Paint()..color = colors.accent);
  }

  void _drawMilestones(
    Canvas canvas,
    double padL,
    double plotW,
    double padT,
    double plotH,
  ) {
    int? takeoffIdx;
    int? m1Idx;
    int? tocIdx;
    int? todIdx;
    int? ldgIdx;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final m = machFn(i);
      final vs = vsFn(i);

      if (takeoffIdx == null && alt > 500) takeoffIdx = i;
      if (m1Idx == null && m >= 1.0) m1Idx = i;
      if (tocIdx == null && alt >= 50000 && m >= 1.95) tocIdx = i;
      if (todIdx == null && i > track.length * 0.6 && vs < -1200) todIdx = i;
      if (alt < 200 && i > track.length * 0.9) ldgIdx = i;
    }

    void flag(int? idx, String label, Color c) {
      if (idx == null || idx < 0 || idx >= track.length) return;
      final x = padL + (idx / (track.length - 1)) * plotW;

      final p = Paint()
        ..color = c.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(x, padT), Offset(x, padT + plotH), p);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: c,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padT - tp.height - 2));
    }

    flag(takeoffIdx, 'TAKEOFF', colors.success);
    flag(m1Idx, 'M1.0', const Color(0xFF8B5CF6));
    flag(tocIdx, 'FL500+', colors.accent);
    flag(todIdx, 'TOD', const Color(0xFF06B6D4));
    flag(ldgIdx, 'TOUCHDOWN', colors.success);
  }

  @override
  bool shouldRepaint(covariant _ProfileChartPainter oldDelegate) {
    return oldDelegate.track.length != track.length ||
        oldDelegate.colors != colors ||
        oldDelegate.mode != mode ||
        oldDelegate.scrubFrac != scrubFrac ||
        oldDelegate.fuelCurve != fuelCurve;
  }
}
