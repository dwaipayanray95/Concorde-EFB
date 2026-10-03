import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../../../widgets/efb_text_field.dart';
import '../../../data/services/lan_link.dart';
import '../../controllers/telemetry_provider.dart';

/// Wi-Fi link between the sim PC and a phone/tablet.
///  - Windows desktop: toggle sharing, show this PC's IP + pairing code.
///  - Android/iOS: find/enter the PC and pair with the code.
/// Shows nothing on other platforms (macOS has no sim bridge).
class WifiLinkCard extends ConsumerWidget {
  const WifiLinkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMobilePlatform) return const _MobileLink();
    if (isWindowsDesktop) return const _DesktopShare();
    return const SizedBox.shrink();
  }
}

Widget _title(BuildContext context, String text, IconData icon) {
  final colors = context.colors;
  return Row(
    children: [
      Icon(icon, size: 15, color: colors.accent),
      const SizedBox(width: 8),
      Text(
        text,
        style: uiText(
          context,
          size: 11,
          weight: FontWeight.w900,
          color: colors.textPrimary,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

Widget _note(BuildContext context, String text, {Color? color}) => Text(
  text,
  style: uiText(
    context,
    size: 10.5,
    weight: FontWeight.w600,
    color: color ?? context.colors.textDim,
    height: 1.4,
  ),
);

Widget _bigValue(BuildContext context, String label, String value) {
  final colors = context.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: uiText(
          context,
          size: 9,
          weight: FontWeight.w800,
          color: colors.textDim,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 2),
      SelectableText(
        value,
        style: uiText(
          context,
          size: 18,
          weight: FontWeight.w900,
          color: colors.accent,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------

class _DesktopShare extends ConsumerWidget {
  const _DesktopShare();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final share = ref.watch(lanShareProvider);
    final ips = ref.watch(localIpv4Provider).value ?? const [];
    final code = share.code.length == 6
        ? '${share.code.substring(0, 3)} ${share.code.substring(3)}'
        : '------';

    return EfbFlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _title(
                  context,
                  'SHARE TO PHONE / TABLET',
                  Icons.wifi_tethering,
                ),
              ),
              Switch(
                value: share.enabled,
                activeThumbColor: colors.accent,
                onChanged: (v) =>
                    ref.read(lanShareProvider.notifier).setEnabled(v),
              ),
            ],
          ),
          if (!share.enabled)
            _note(
              context,
              'Turn on to show this Flight Monitor live on the Concorde EFB '
              'app on your phone or tablet (same Wi-Fi network).',
            )
          else ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _bigValue(
                  context,
                  'THIS PC',
                  ips.isEmpty ? 'NO NETWORK' : ips.join('  /  '),
                ),
                _bigValue(context, 'PAIRING CODE', code),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(lanShareProvider.notifier).regenerateCode(),
                  icon: Icon(Icons.refresh, size: 14, color: colors.accent),
                  label: Text(
                    'NEW CODE',
                    style: uiText(
                      context,
                      size: 10,
                      weight: FontWeight.w800,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _note(
              context,
              'On the phone/tablet open MONITOR -- this PC should appear '
              'automatically; enter the pairing code. If Windows asks about '
              'msfs_bridge, allow it on Private networks.',
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MobileLink extends ConsumerStatefulWidget {
  const _MobileLink();

  @override
  ConsumerState<_MobileLink> createState() => _MobileLinkState();
}

class _MobileLinkState extends ConsumerState<_MobileLink> {
  String _host = '';
  String _code = '';
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remote = ref.watch(remoteBridgeProvider);
    final monitor = ref.watch(flightMonitorProvider);
    final live = monitor.isConnected;
    final reachable = monitor.bridge.socketConnected;

    // Paired and the PC answers: one compact status row.
    if (remote.isConfigured && !_editing) {
      final (text, color) = monitor.bridge.pairingRejected
          ? ('PAIRING CODE REJECTED -- CHECK THE CODE ON THE PC', colors.error)
          : live
          ? ('LIVE FROM ${remote.host}', colors.success)
          : reachable
          ? (
              'CONNECTED TO ${remote.host} -- ${monitor.bridge.message.toUpperCase()}',
              colors.accent,
            )
          : (
              'CAN\'T REACH ${remote.host} -- IS THE DESKTOP APP OPEN WITH '
                  'SHARING ON, ON THE SAME WI-FI?',
              colors.accent,
            );
      return EfbFlatCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.wifi, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: uiText(
                  context,
                  size: 11,
                  weight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _editing = true;
                _host = remote.host;
                _code = remote.code;
              }),
              child: Text(
                'CHANGE',
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w800,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final found = ref.watch(discoveredBridgesProvider).value ?? const [];
    final canConnect =
        _host.trim().isNotEmpty && RegExp(r'^\d{6}$').hasMatch(_code.trim());

    return EfbFlatCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, 'CONNECT TO YOUR SIM PC', Icons.wifi_find),
          const SizedBox(height: 6),
          _note(
            context,
            'Live sim data comes from the Concorde EFB desktop app on the PC '
            'running MSFS. On the PC open MONITOR, turn on "Share to phone / '
            'tablet", then enter its pairing code here. Both devices must be '
            'on the same Wi-Fi.',
          ),
          const SizedBox(height: 12),
          if (found.isEmpty)
            _note(context, 'Searching for PCs on this network...')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in found)
                  ChoiceChip(
                    label: Text(
                      '${b.name}  ${b.ip}',
                      style: uiText(
                        context,
                        size: 11,
                        weight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    selected: _host == b.ip,
                    selectedColor: colors.accent,
                    onSelected: (_) => setState(() => _host = b.ip),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: EfbTextField(
                  key: ValueKey('host-$_host'),
                  label: 'PC ADDRESS',
                  initialValue: _host,
                  placeholder: '192.168.1.20',
                  keyboardType: TextInputType.url,
                  onChanged: (v) => _host = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: EfbTextField(
                  label: 'PAIRING CODE',
                  initialValue: _code,
                  placeholder: '6 digits',
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _code = v.replaceAll(RegExp(r'\D'), '')),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: AppColors.dark.bg,
                    disabledBackgroundColor: colors.dividerStrong,
                  ),
                  onPressed: canConnect
                      ? () async {
                          await ref
                              .read(remoteBridgeProvider.notifier)
                              .connect(_host, _code);
                          if (mounted) setState(() => _editing = false);
                        }
                      : null,
                  child: Text(
                    'CONNECT',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w900,
                      color: AppColors.dark.bg,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_editing && remote.isConfigured) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await ref.read(remoteBridgeProvider.notifier).forget();
                  if (mounted) setState(() => _editing = false);
                },
                child: Text(
                  'FORGET THIS PC',
                  style: uiText(
                    context,
                    size: 10,
                    weight: FontWeight.w800,
                    color: colors.error,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
