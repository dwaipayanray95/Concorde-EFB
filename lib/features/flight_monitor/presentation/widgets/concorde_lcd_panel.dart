import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:concorde_efb/providers/efb_providers.dart';
import '../../data/models/telemetry_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Vivid avionics color palette
// ─────────────────────────────────────────────────────────────────────────────
const _kAccent      = Color(0xFF00E5FF);   // electric cyan
const _kAccentGlow  = Color(0x5500E5FF);   // cyan glow — used in box shadows

const _kGreen       = Color(0xFF00E676);   // bright emerald
const _kAmber       = Color(0xFFFFAB40);   // amber warning
const _kRed         = Color(0xFFFF5252);   // alert red
const _kBg          = Color(0xFF050D1A);   // deep navy-black
const _kPanelBg     = Color(0xFF0B1628);   // slightly lighter navy
const _kCard        = Color(0xFF0F1F38);   // card inner bg
const _kBorder      = Color(0xFF1B3A5C);   // visible border

const _kLabel       = Color(0xFF8ECAE6);   // bright blue-grey label
const _kMuted       = Color(0xFF546E7A);   // muted text
const _kSky         = Color(0xFF0D47A1);   // real horizon blue
const _kGround      = Color(0xFF4A2900);   // earth brown

TextStyle _mono({
  double size = 11,
  Color color = Colors.white,
  FontWeight weight = FontWeight.bold,
}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

TextStyle _label({double size = 9, Color color = _kLabel}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, color: color, fontWeight: FontWeight.w700, letterSpacing: 1.0);

// ─────────────────────────────────────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────────────────────────────────────
class ConcordeLcdPanel extends ConsumerWidget {
  final TelemetryModel telemetry;
  final bool isConnected;

  const ConcordeLcdPanel({
    super.key,
    required this.telemetry,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = telemetry;

    // Derived values

    final bool anyReheat = t.reheatActive.any((v) => v);
    final bool cgWarning = t.cgPct < t.cgFwdLimit || t.cgPct > t.cgAftLimit;
    final bool overspeed = t.ias > 380 || t.mach > 2.04;
    final bool slowSpeed = t.ias < 150 && t.altitude > 1000;
    final bool tempWarn = t.tat >= 121.0;
    final bool tempCrit = t.tat >= 127.0;

    // Annunciations
    final List<_Alert> alerts = [
      if (overspeed) const _Alert('OVERSPEED EXCEEDANCE', _kRed),
      if (slowSpeed) const _Alert('LOW IAS / STALL RISK', _kRed),
      if (tempCrit) const _Alert('NOSE TEMP CRITICAL >127°C', _kRed),
      if (tempWarn && !tempCrit) const _Alert('NOSE TEMP WARNING >121°C', _kAmber),
      if (cgWarning) const _Alert('CG LIMIT EXCEEDANCE', Colors.orangeAccent),
      if (!isConnected) const _Alert('SIMCONNECT DISCONNECTED', Colors.blueAccent),
    ];

    final fuelBreakdown = ref.watch(fuelBreakdownProvider);


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top annunciator bar ──────────────────────────────────────────
        _AlertBar(alerts: alerts, isConnected: isConnected, zuluTime: t.zuluTime),
        const SizedBox(height: 12),

        // ── Main grid (flat — parent scroll view handles scrolling) ──────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: PFD | Airspeed | Altimeter/VSI | Compass
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: _PfdModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _AirspeedModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _AltimeterModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _CompassModule(t: t, isConnected: isConnected)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Row 2: EICAS × 4 engines | Fuel | CG+Thermal
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _EicasModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: _FuelModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: _SystemsModule(t: t, isConnected: isConnected, cgWarning: cgWarning, tempWarn: tempWarn, tempCrit: tempCrit)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Row 3: Concorde-specific extras
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: _ConcordeDroopGearModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: _ReheatIcingModule(t: t, isConnected: isConnected, anyReheat: anyReheat)),
                    const SizedBox(width: 10),
                    Expanded(flex: 5, child: _EnduranceModule(t: t, isConnected: isConnected, fuelBreakdown: fuelBreakdown)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
//  Alert bar
// ─────────────────────────────────────────────────────────────────────────────
class _Alert {
  final String text;
  final Color color;
  const _Alert(this.text, this.color);
}

class _AlertBar extends StatefulWidget {
  final List<_Alert> alerts;
  final bool isConnected;
  final String zuluTime;

  const _AlertBar({required this.alerts, required this.isConnected, required this.zuluTime});

  @override
  State<_AlertBar> createState() => _AlertBarState();
}

class _AlertBarState extends State<_AlertBar> with SingleTickerProviderStateMixin {
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
            color: hasWarning ? _kRed.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.2),
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
                  color: _kRed.withValues(alpha: _pulse.value),
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
            style: _mono(
              size: 10,
              color: hasWarning ? _kRed : Colors.greenAccent,
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
            style: _mono(size: 10, color: _kMuted),
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
              style: _mono(
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
      child: Text(text, style: _mono(size: 8, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared panel shell
// ─────────────────────────────────────────────────────────────────────────────
class _Panel extends StatelessWidget {
  final String title;
  final String tag;
  final Color tagColor;
  final Widget child;

  const _Panel({
    required this.title,
    required this.tag,
    required this.child,
    this.tagColor = _kAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: _kAccent.withValues(alpha: 0.08), blurRadius: 18, spreadRadius: -2),
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
                    style: _label(size: 9, color: _kAccent),
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
                  child: Text(tag, style: _mono(size: 7, color: tagColor)),
                ),
              ],
            ),
          ),
          Divider(color: _kBorder, height: 14, thickness: 1),
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

// ─────────────────────────────────────────────────────────────────────────────
//  01 // PFD — Attitude Horizon
// ─────────────────────────────────────────────────────────────────────────────
class _PfdModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _PfdModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final pitch = isConnected ? t.pitch : 0.0;
    final roll = isConnected ? t.roll : 0.0;

    return _Panel(
      title: '01 // ATTITUDE HORIZON',
      tag: 'LIVE',
      child: Column(
        children: [
          // Horizon box
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder, width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Rolling horizon
                Center(
                  child: Transform.rotate(
                    angle: roll * 3.14159 / 180.0,
                    child: Transform.translate(
                      offset: Offset(0, pitch * 3.5),
                      child: SizedBox(
                        width: 600,
                        height: 600,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                color: _kSky,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: _pitchLines(isSky: true),
                                ),
                              ),
                            ),
                            Container(height: 1.5, color: Colors.white),
                            Expanded(
                              child: Container(
                                color: _kGround,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: _pitchLines(isSky: false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Aircraft reference
                Center(
                  child: CustomPaint(
                    size: const Size(100, 30),
                    painter: _AircraftPainter(),
                  ),
                ),

                // Roll/Pitch corner readouts
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: _cornerBadge('ROLL', '${roll.toStringAsFixed(1)}°', roll.abs() > 30 ? _kAmber : Colors.white70),
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: _cornerBadge('PITCH', '${pitch.toStringAsFixed(1)}°', pitch.abs() > 15 ? _kAmber : Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // G-Force row
          Row(
            children: [
              Expanded(child: _dataCell('G-FORCE', '${t.gForce.toStringAsFixed(2)} G', t.gForce > 2.0 ? _kAmber : _kAccent)),
              const SizedBox(width: 6),
              Expanded(child: _dataCell('GND SPD', '${t.gs.round()} KTS')),
              const SizedBox(width: 6),
              Expanded(child: _dataCell('TAS', '${t.tas.round()} KTS')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pitchLines({required bool isSky}) {
    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: isSky ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [10, 20].map((deg) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: isSky ? 4 : 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${isSky ? '' : '-'}$deg', style: _mono(size: 7, color: Colors.white24)),
                Container(width: 30, height: 1, color: Colors.white24),
                const SizedBox(width: 4),
                Container(width: 30, height: 1, color: Colors.white24),
                Text('${isSky ? '' : '-'}$deg', style: _mono(size: 7, color: Colors.white24)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _cornerBadge(String label, String val, Color valColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: _mono(size: 9, color: _kLabel, weight: FontWeight.normal)),
          Text(val, style: _mono(size: 9, color: valColor)),
        ],
      ),
    );
  }

  Widget _dataCell(String label, String val, [Color valColor = Colors.white]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _label(size: 9)),
          const SizedBox(height: 3),
          Text(val, style: _mono(size: 13, color: valColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  02 // AIRSPEED
// ─────────────────────────────────────────────────────────────────────────────
class _AirspeedModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _AirspeedModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final ias = isConnected ? t.ias : 0.0;
    final mach = isConnected ? t.mach : 0.0;

    const redlineKts = 380.0;
    const stallKts = 150.0;

    // Build tape ticks
    final int base = (ias / 20).floor() * 20;
    final ticks = List.generate(9, (i) => base - 80 + i * 20);

    return _Panel(
      title: '02 // AIRSPEED PERFORMANCE',
      tag: 'VNE WARNINGS',
      child: Column(
        children: [
          // Tape
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Left caution stripe
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: _cautionStripe(),
                ),

                // Scrolling ticks
                ...ticks.where((v) => v >= 0).map((v) {
                  final dy = (ias - v) * 1.6;
                  final isStall = v <= stallKts;
                  final isOver = v >= redlineKts;
                  return Positioned(
                    right: 0,
                    top: 0,
                    left: 6,
                    child: Transform.translate(
                      offset: Offset(0, -dy + 88),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$v',
                            style: _mono(
                              size: 9,
                              color: isStall ? _kRed : isOver ? Colors.orangeAccent : _kMuted,
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 1.5,
                            color: isStall ? _kRed : isOver ? Colors.orangeAccent : _kBorder,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Central readout
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kAccent, width: 2),
                      boxShadow: [
                        BoxShadow(color: _kAccentGlow, blurRadius: 16),
                        BoxShadow(color: _kAccent.withValues(alpha: 0.15), blurRadius: 40),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('IAS', style: _label(size: 9, color: _kAccent)),
                        Text(
                          ias.round().toString(),
                          style: _mono(size: 32, color: Colors.white),
                        ),
                        Text('KTS', style: _label(size: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _infoCell(
                  'MACH',
                  'M ${mach.toStringAsFixed(3)}',
                  mach >= 1.0 ? Colors.orangeAccent : Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _infoCell(
                  'TREND',
                  ias > 380 ? '▼ DECEL' : ias > 300 ? '▲ ACCEL' : '■ STABLE',
                  ias > 380 ? _kRed : _kAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _cautionStripe() {
  return CustomPaint(painter: _CautionStripePainter());
}

// ─────────────────────────────────────────────────────────────────────────────
//  03 // ALTIMETER + VSI
// ─────────────────────────────────────────────────────────────────────────────
class _AltimeterModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _AltimeterModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final alt = isConnected ? t.altitude : 0.0;
    final vs = isConnected ? t.vs : 0.0;
    final fl = (alt / 100).round();

    final int base = (alt / 500).floor() * 500;
    final ticks = List.generate(7, (i) => base - 1500 + i * 500);

    return _Panel(
      title: '03 // ALTIMETER & VSI',
      tag: 'BARO SYNC',
      tagColor: Colors.greenAccent,
      child: Column(
        children: [
          // Tape row
          Row(
            children: [
              // Altitude tape
              Expanded(
                flex: 3,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorder),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ...ticks.where((v) => v >= 0).map((v) {
                        final dy = (alt - v) * 0.048;
                        return Positioned(
                          right: 0,
                          left: 0,
                          top: 0,
                          child: Transform.translate(
                            offset: Offset(0, -dy + 88),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${v ~/ 100}', style: _mono(size: 8, color: _kMuted)),
                                Container(width: 10, height: 1, color: _kBorder),
                              ],
                            ),
                          ),
                        );
                      }),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _kGreen, width: 2),
                            boxShadow: [
                              BoxShadow(color: _kGreen.withValues(alpha: 0.35), blurRadius: 16),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('ALT FT', style: _label(size: 8, color: _kGreen)),
                              Text(
                                alt.round().toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (m) => '${m[1]},',
                                ),
                                style: _mono(size: 18, color: Colors.white),
                              ),
                              Text('FL${fl.toString().padLeft(3, '0')}', style: _mono(size: 10, color: _kGreen)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // VSI
              Container(
                width: 48,
                height: 200,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VSI', style: _label(size: 7)),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: _VsiBar(vs: vs),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${vs >= 0 ? '+' : ''}${vs.round()}',
                      style: _mono(size: 8, color: vs >= 0 ? Colors.greenAccent : _kRed),
                    ),
                    Text('ft/m', style: _label(size: 7)),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VsiBar extends StatelessWidget {
  final double vs;
  const _VsiBar({required this.vs});

  @override
  Widget build(BuildContext context) {
    final frac = (vs.abs() / 2500.0).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: _kBorder,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: vs >= 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: frac,
          child: Container(
            decoration: BoxDecoration(
              color: vs >= 0 ? Colors.greenAccent : _kRed,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  04 // COMPASS
// ─────────────────────────────────────────────────────────────────────────────
class _CompassModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _CompassModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final hdg = isConnected ? t.heading : 0.0;

    return _Panel(
      title: '04 // HEADING & COMPASS',
      tag: 'GPS',
      tagColor: _kAmber,
      child: Column(
        children: [
          // Compass tape
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _CompassTapePainter(heading: hdg)),
                // Center index
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(width: 1.5, height: 10, color: _kRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _bigCell('HDG', '${hdg.round().toString().padLeft(3, '0')}°', Colors.white),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _bigCell('TRK', '${t.gs > 5 ? ((hdg + t.roll * 0.1) % 360).round().toString().padLeft(3, '0') : '---'}°', _kAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(child: _infoCell('LATITUDE', _fmtDeg(t.latitude, 'N', 'S'))),
              const SizedBox(width: 6),
              Expanded(child: _infoCell('LONGITUDE', _fmtDeg(t.longitude, 'E', 'W'))),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDeg(double val, String pos, String neg) {
    final d = val.abs();
    final deg = d.floor();
    final min = ((d - deg) * 60).toStringAsFixed(2);
    return '${val >= 0 ? pos : neg}$deg° $min\'';
  }
}

Widget _bigCell(String label, String val, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBorder, width: 1.5),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10)],
    ),
    child: Column(
      children: [
        Text(label, style: _label(size: 9)),
        const SizedBox(height: 4),
        Text(val, style: _mono(size: 22, color: color)),
      ],
    ),
  );
}

Widget _infoCell(String label, String val, [Color valColor = Colors.white]) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _kBorder),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: _label(size: 8),
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
              style: _mono(size: 10, color: valColor),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  05 // EICAS — 4× Olympus 593 Engines
// ─────────────────────────────────────────────────────────────────────────────
class _EicasModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _EicasModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final n1 = isConnected ? ((t.ias / 4.5) + 62.0).clamp(0.0, 100.0) : 0.0;
    final egt = isConnected ? (520.0 + n1 * 1.5) : 0.0;
    final totalFlow = isConnected ? t.fuelBurnTotal : 0.0;

    return _Panel(
      title: '05 // ENGINE TELEMETRY (EICAS)',
      tag: 'OLYMPUS 593',
      tagColor: Colors.greenAccent,
      child: Column(
        children: [
          // 4 engine blocks side by side
          Row(
            children: List.generate(4, (i) {
              final reheat = isConnected && t.reheatActive.length > i && t.reheatActive[i];
              // Slight engine-to-engine variation
              final engineN1 = n1 + (i.isOdd ? 0.3 : -0.2);
              final engineEgt = egt + (i.isOdd ? 3.0 : -2.0);

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: reheat
                          ? Colors.orangeAccent.withValues(alpha: 0.4)
                          : _kBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('ENG ${i + 1}', style: _label(size: 9)),
                      const SizedBox(height: 8),

                      // N1 bar
                      _engineBar('N1', engineN1, 100.0, engineN1 > 90 ? _kAmber : Colors.greenAccent),
                      const SizedBox(height: 6),

                      // EGT bar
                      _engineBar('EGT', engineEgt, 900.0, engineEgt > 750 ? _kRed : engineEgt > 680 ? _kAmber : _kAccent),
                      const SizedBox(height: 10),

                      // Reheat dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: reheat ? Colors.orangeAccent : _kBorder,
                              boxShadow: reheat
                                  ? [const BoxShadow(color: Colors.orangeAccent, blurRadius: 6)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('REHEAT', style: _mono(size: 7, color: reheat ? Colors.orangeAccent : _kMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Total flow + EGT readout
          Row(
            children: [
              Expanded(
                child: _infoCell(
                  'TOTAL FUEL FLOW',
                  '${totalFlow.round()} KG/HR',
                  _kAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _infoCell(
                  'CORE EGT AVG',
                  '${egt.round()} °C',
                  egt > 750 ? _kRed : Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _engineBar(String label, double val, double max, Color barColor) {
    final frac = (val / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: _label(size: 7)),
            Text(
              val > 100 ? '${val.round()}°' : '${val.toStringAsFixed(1)}%',
              style: _mono(size: 8, color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: frac,
            backgroundColor: _kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  06 // FUEL MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────
class _FuelModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _FuelModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    // The model stores fill percentages 0→1; convert to indicative kg using max capacities
    final lKg = (isConnected ? t.fuelLeftTank : 0.0) * 17483.0;
    final rKg = (isConnected ? t.fuelRightTank : 0.0) * 17483.0;
    final cKg = (isConnected ? t.fuelCenterTank : 0.0) * 11793.0;
    final fwdKg = (isConnected ? t.fuelTrimForward : 0.0) * 10000.0;
    final aftKg = (isConnected ? t.fuelTrimAft : 0.0) * 5681.0;
    final total = lKg + rKg + cKg + fwdKg + aftKg;
    final imbalance = (lKg - rKg).abs();
    final burnRate = isConnected ? t.fuelBurnTotal : 0.0;
    final endurance = burnRate > 0 ? total / burnRate : 0.0;

    return _Panel(
      title: '06 // FUEL MANAGEMENT SYSTEM',
      tag: 'WEIGHT KG',
      tagColor: Colors.orangeAccent,
      child: Column(
        children: [
          // Total FOB
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_gas_station, color: _kAccent, size: 14),
                    const SizedBox(width: 6),
                    Text('FOB (FUEL ON BOARD)', style: _label(size: 9)),
                  ],
                ),
                Text(
                  '${_fmtKg(total)} KG',
                  style: _mono(size: 14, color: total < 5000 ? _kRed : Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Wing tanks
          Row(
            children: [
              Expanded(child: _tankCell('L WING', lKg, 17483.0)),
              const SizedBox(width: 6),
              Expanded(child: _tankCell('R WING', rKg, 17483.0)),
            ],
          ),
          const SizedBox(height: 6),

          // Center + trim tanks
          Row(
            children: [
              Expanded(child: _tankCell('CENTER', cKg, 11793.0)),
              const SizedBox(width: 6),
              Expanded(child: _tankCell('TRIM FWD', fwdKg, 10000.0)),
              const SizedBox(width: 6),
              Expanded(child: _tankCell('TRIM AFT', aftKg, 5681.0)),
            ],
          ),
          const SizedBox(height: 8),

          // Imbalance + burn
          _infoCell('IMBALANCE DELTA', '${_fmtKg(imbalance)} KG', imbalance > 500 ? _kAmber : Colors.white70),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _infoCell('BURN RATE', '${burnRate.round()} KG/HR')),
              const SizedBox(width: 6),
              Expanded(child: _infoCell('ENDURANCE', '${endurance.toStringAsFixed(2)} HRS', Colors.greenAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tankCell(String label, double val, double cap) {
    final frac = (val / cap).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _label(size: 7)),
          const SizedBox(height: 2),
          Text(_fmtKg(val), style: _mono(size: 10)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: frac,
              backgroundColor: _kBorder,
              valueColor: AlwaysStoppedAnimation<Color>(frac < 0.15 ? _kRed : _kAccent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtKg(double v) {
    final str = v.round().toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(str[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  07 // SYSTEMS — CG & Thermal
// ─────────────────────────────────────────────────────────────────────────────
class _SystemsModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;
  final bool cgWarning;
  final bool tempWarn;
  final bool tempCrit;

  const _SystemsModule({
    required this.t,
    required this.isConnected,
    required this.cgWarning,
    required this.tempWarn,
    required this.tempCrit,
  });

  @override
  Widget build(BuildContext context) {
    final cg = isConnected ? t.cgPct : 53.5;
    final tat = isConnected ? t.tat : 15.0;
    final fwdLim = isConnected ? t.cgFwdLimit : 52.0;
    final aftLim = isConnected ? t.cgAftLimit : 59.0;

    // CG bar position 50%→65% range mapped to bar width
    final cgNorm = ((cg - 50.0) / 15.0).clamp(0.0, 1.0);
    final fwdNorm = ((fwdLim - 50.0) / 15.0).clamp(0.0, 1.0);
    final aftNorm = ((aftLim - 50.0) / 15.0).clamp(0.0, 1.0);

    return _Panel(
      title: '07 // CG & THERMAL SYSTEMS',
      tag: 'OP-SAFETY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CG section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CG POSITION', style: _label(size: 9)),
                  Text('FWD ${fwdLim.toStringAsFixed(1)}% — AFT ${aftLim.toStringAsFixed(1)}%', style: _label(size: 7, color: _kMuted)),
                ],
              ),
              Text(
                '${cg.toStringAsFixed(1)}%',
                style: _mono(size: 18, color: cgWarning ? _kRed : Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // CG bar with limit markers
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kBorder),
                ),
              ),
              // Safe zone highlight
              Positioned(
                left: MediaQuery.sizeOf(context).width * 0.0 + fwdNorm * 100,
                width: (aftNorm - fwdNorm) * 100,
                top: 2,
                bottom: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // CG pointer
              Align(
                alignment: Alignment(cgNorm * 2 - 1, 0),
                child: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cgWarning ? _kRed : _kAccent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: (cgWarning ? _kRed : _kAccent).withValues(alpha: 0.5), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // TAT section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL AIR TEMP (TAT)', style: _label(size: 9)),
                  Text('NOSE STRUCTURAL LIMIT: 127°C', style: _label(size: 7, color: _kMuted)),
                ],
              ),
              Text(
                '${tat.round()}°C',
                style: _mono(
                  size: 18,
                  color: tempCrit ? _kRed : tempWarn ? _kAmber : Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (tat / 150.0).clamp(0.0, 1.0),
              backgroundColor: _kBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                tempCrit ? _kRed : tempWarn ? _kAmber : Colors.greenAccent,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  08 // CONCORDE DROOP, GEAR & GEOMETRY
// ─────────────────────────────────────────────────────────────────────────────
class _ConcordeDroopGearModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const _ConcordeDroopGearModule({required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final snoot = isConnected ? t.snootAngle : 0.0;
    final gearPct = isConnected ? t.gearPosition : 0.0;
    final gearDown = gearPct > 0.8;
    final gearInTransit = gearPct > 0.05 && gearPct < 0.95;

    return _Panel(
      title: '08 // DROOP NOSE & GEAR',
      tag: 'CONCORDE',
      tagColor: Colors.purpleAccent,
      child: Column(
        children: [
          // Nose droop visual
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                // Animated droop indicator
                CustomPaint(
                  size: const Size(120, 60),
                  painter: _DroopNosePainter(angle: snoot),
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NOSE DROOP', style: _label(size: 8)),
                    Text(
                      '${snoot.toStringAsFixed(1)}°',
                      style: _mono(size: 22, color: snoot > 0 ? _kAmber : _kAccent),
                    ),
                    Text(
                      snoot >= 12.5 ? 'FULLY DOWN' : snoot >= 5.0 ? 'PARTIAL' : 'RETRACTED',
                      style: _mono(size: 9, color: snoot > 0 ? _kAmber : _kMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Gear status
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gearDown
                        ? Colors.greenAccent.withValues(alpha: 0.08)
                        : gearInTransit
                            ? _kAmber.withValues(alpha: 0.08)
                            : _kBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: gearDown
                          ? Colors.greenAccent.withValues(alpha: 0.3)
                          : gearInTransit
                              ? _kAmber.withValues(alpha: 0.3)
                              : _kBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LANDING GEAR', style: _label(size: 9)),
                      Text(
                        gearDown ? '▼ DOWN' : gearInTransit ? '⟳ TRANSIT' : '▲ UP',
                        style: _mono(
                          size: 11,
                          color: gearDown
                              ? Colors.greenAccent
                              : gearInTransit
                                  ? _kAmber
                                  : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _infoCell('FLAPS', 'POS ${t.flapsPosition}')),
              const SizedBox(width: 6),
              Expanded(child: _infoCell('G FORCE', '${t.gForce.toStringAsFixed(2)} G', t.gForce > 1.5 ? _kAmber : _kAccent)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  09 // REHEAT & ICING STATUS
// ─────────────────────────────────────────────────────────────────────────────
class _ReheatIcingModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;
  final bool anyReheat;

  const _ReheatIcingModule({required this.t, required this.isConnected, required this.anyReheat});

  @override
  Widget build(BuildContext context) {
    final tat = isConnected ? t.tat : 15.0;
    // Icing risk: TAT between -40 and +2 °C is the classic airframe icing envelope
    final icingRisk = isConnected && tat >= -40.0 && tat <= 2.0;

    return _Panel(
      title: '09 // REHEAT & ICING STATUS',
      tag: 'SAFETY',
      tagColor: _kAmber,
      child: Column(
        children: [
          // 4 reheat indicators
          Text('OLYMPUS 593 AFTERBURNER STATUS', style: _label(size: 8)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final active = isConnected && t.reheatActive.length > i && t.reheatActive[i];
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? Colors.orangeAccent.withValues(alpha: 0.1) : _kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? Colors.orangeAccent.withValues(alpha: 0.5) : _kBorder,
                      width: active ? 1.5 : 1.0,
                    ),
                    boxShadow: active ? [const BoxShadow(color: Colors.orangeAccent, blurRadius: 12, spreadRadius: -2)] : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 20,
                        color: active ? Colors.orangeAccent : _kMuted,
                      ),
                      const SizedBox(height: 4),
                      Text('ENG\n${i + 1}', textAlign: TextAlign.center, style: _label(size: 8, color: active ? Colors.orangeAccent : _kMuted)),
                      const SizedBox(height: 2),
                      Text(
                        active ? 'ON' : 'OFF',
                        style: _mono(size: 9, color: active ? Colors.orangeAccent : _kMuted),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Icing detection
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: icingRisk
                  ? Colors.blueAccent.withValues(alpha: 0.08)
                  : Colors.greenAccent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: icingRisk
                    ? Colors.blueAccent.withValues(alpha: 0.35)
                    : Colors.greenAccent.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.ac_unit,
                  size: 18,
                  color: icingRisk ? Colors.blueAccent : Colors.greenAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ICING RISK ENVELOPE', style: _label(size: 9)),
                      Text(
                        icingRisk
                            ? 'WARNING: TAT ${tat.round()}°C — ICING CONDITIONS'
                            : 'CLEAR — TAT ${tat.round()}°C  (safe)',
                        style: _mono(size: 9, color: icingRisk ? Colors.blueAccent : Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _infoCell(
            'REHEAT SUMMARY',
            anyReheat ? '${t.reheatActive.where((v) => v).length}/4 ACTIVE' : 'ALL OFF',
            anyReheat ? Colors.orangeAccent : Colors.white70,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  10 // ENDURANCE CALCULATOR
// ─────────────────────────────────────────────────────────────────────────────
class _EnduranceModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;
  final dynamic fuelBreakdown;

  const _EnduranceModule({required this.t, required this.isConnected, required this.fuelBreakdown});

  @override
  Widget build(BuildContext context) {
    final totalFuelKg = isConnected
        ? (t.fuelLeftTank * 17483 + t.fuelRightTank * 17483 + t.fuelCenterTank * 11793 +
              t.fuelTrimForward * 10000 + t.fuelTrimAft * 5681)
        : 0.0;
    final burnRate = isConnected ? t.fuelBurnTotal : 0.0;
    final alt = isConnected ? t.altitude : 0.0;
    final mach = isConnected ? t.mach : 0.0;
    final vs = isConnected ? t.vs : 0.0;

    // Phase detection
    String phase = 'Subsonic';
    double phaseRate = 12000;
    if (mach >= 2.0 && alt >= 50000) {
      phase = 'Mach 2.0 Cruise';
      phaseRate = 21500;
    } else if (mach >= 1.0) {
      phase = 'Supersonic';
      phaseRate = 24000;
    } else if (vs > 500) {
      phase = 'Climb / Accel';
      phaseRate = 28000;
    } else if (vs < -500) {
      phase = 'Descent';
      phaseRate = 5000;
    }

    final phaseEndurance = burnRate > 0 ? totalFuelKg / burnRate : totalFuelKg / phaseRate;
    final subsonicEndurance = totalFuelKg / 12000;
    final holdingEndurance = totalFuelKg / 6000;

    final reservesKg = fuelBreakdown != null
        ? (fuelBreakdown.finalReserveKg + fuelBreakdown.alternateKg + fuelBreakdown.contingencyKg)
        : 0.0;
    final isLowFuel = reservesKg > 0 && totalFuelKg < reservesKg;

    return _Panel(
      title: '10 // PROFILE ENDURANCE CALCULATOR',
      tag: 'FMS PROJECTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary adaptive readout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLowFuel ? _kRed.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADAPTIVE ENDURANCE', style: _label(size: 9)),
                    Text('Phase: $phase', style: _mono(size: 8, color: _kAccent.withValues(alpha: 0.7))),
                  ],
                ),
                Text(
                  '${phaseEndurance.toStringAsFixed(2)} HRS',
                  style: _mono(size: 22, color: isLowFuel ? _kRed : Colors.greenAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _enduranceRow('Subsonic Escape Range', subsonicEndurance, '12,000 kg/hr'),
          const SizedBox(height: 6),
          _enduranceRow('Max Holding Pattern', holdingEndurance, '6,000 kg/hr'),
          const SizedBox(height: 8),

          if (isLowFuel)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _kRed, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'FUEL BELOW PLANNED RESERVES',
                      style: _mono(size: 9, color: _kRed),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _enduranceRow(String label, double hrs, String burnNote) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _label(size: 9)),
            Text(burnNote, style: _mono(size: 7, color: _kMuted, weight: FontWeight.normal)),
          ],
        ),
        Text('${hrs.toStringAsFixed(2)} hrs', style: _mono(size: 12, color: Colors.white)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

class _AircraftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _kAmber
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = _kRed;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path()
      ..moveTo(0, cy)
      ..lineTo(cx - 18, cy)
      ..lineTo(cx - 12, cy + 6)
      ..lineTo(cx, cy)
      ..lineTo(cx + 12, cy + 6)
      ..lineTo(cx + 18, cy)
      ..lineTo(size.width, cy);

    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(cx, cy), 3, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DroopNosePainter extends CustomPainter {
  final double angle; // 0 = retracted, 12.5 = fully down

  const _DroopNosePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = _kAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cy = size.height * 0.45;

    // Fuselage body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, cy - 8, size.width - 40, 16),
        const Radius.circular(4),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, cy - 8, size.width - 40, 16),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // Droop nose pivot
    final droopAngleRad = angle * 3.14159 / 180.0;
    canvas.save();
    canvas.translate(20, cy);
    canvas.rotate(droopAngleRad * 1.2);

    final nosePath = Path()
      ..moveTo(0, 0)
      ..lineTo(-22, -5)
      ..lineTo(-22, 5)
      ..close();
    canvas.drawPath(nosePath, bodyPaint);
    canvas.drawPath(nosePath, borderPaint..color = angle > 0 ? _kAmber : _kAccent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DroopNosePainter old) => old.angle != angle;
}

class _CompassTapePainter extends CustomPainter {
  final double heading;

  const _CompassTapePainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final tickPaint = Paint()
      ..color = _kMuted
      ..strokeWidth = 1.0;

    final cx = size.width / 2;

    for (int d = (heading - 45).floor(); d <= (heading + 45); d++) {
      final norm = (d + 360) % 360;
      final x = cx + (d - heading) * 4.0;
      if (x < 0 || x > size.width) continue;

      if (norm % 5 == 0) {
        canvas.drawLine(Offset(x, size.height - 10), Offset(x, size.height), tickPaint);

        if (norm % 10 == 0) {
          String lbl;
          if (norm == 0) { lbl = 'N'; }
          else if (norm == 90) { lbl = 'E'; }
          else if (norm == 180) { lbl = 'S'; }
          else if (norm == 270) { lbl = 'W'; }
          else { lbl = norm.toString().padLeft(3, '0'); }

          final isCardinal = lbl.length == 1;

          tp.text = TextSpan(
            text: lbl,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isCardinal ? _kAccent : _kMuted,
            ),
          );
          tp.layout();
          tp.paint(canvas, Offset(x - tp.width / 2, 4));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CompassTapePainter old) => old.heading != heading;
}

class _CautionStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const stripes = 8;
    final h = size.height / stripes;

    for (int i = 0; i < stripes; i++) {
      paint.color = i.isEven
          ? _kRed.withValues(alpha: 0.5)
          : Colors.greenAccent.withValues(alpha: 0.5);
      canvas.drawRect(Rect.fromLTWH(0, i * h, size.width, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
