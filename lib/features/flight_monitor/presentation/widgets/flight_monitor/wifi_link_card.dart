import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../../../widgets/efb_text_field.dart';
import '../../../data/services/lan_link.dart';
import '../../controllers/telemetry_provider.dart';
import 'android_beta_prompt.dart';

/// Wi-Fi link between the sim PC and a secondary device (phone, tablet, Mac).
///  - Windows desktop: toggle sharing, show this PC's IP + pairing code.
///  - Remote clients (Mac, Android, iOS): find/enter the PC and pair with the code.
class WifiLinkCard extends ConsumerWidget {
  const WifiLinkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isRemoteClientPlatform) return const _RemoteLink();
    if (isWindowsDesktop) return const _DesktopShare();
    return const SizedBox.shrink();
  }
}

Widget _title(
  BuildContext context,
  String text,
  IconData icon, {
  String? helpTooltip,
  Widget? trailing,
}) {
  final colors = context.colors;
  return Row(
    children: [
      Icon(icon, size: 14, color: colors.accent),
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
      if (helpTooltip != null) ...[
        const SizedBox(width: 6),
        Tooltip(
          message: helpTooltip,
          triggerMode: TooltipTriggerMode.tap,
          preferBelow: true,
          waitDuration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: uiText(
            context,
            size: 10.5,
            weight: FontWeight.w600,
            color: colors.textPrimary,
            height: 1.4,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.dividerStrong, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.help,
            child: Icon(
              Icons.help_outline_rounded,
              size: 14,
              color: colors.accent,
            ),
          ),
        ),
      ],
      if (trailing != null) ...[
        const Spacer(),
        trailing,
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _title(
                  context,
                  'SHARE TO PHONE / TABLET / MAC',
                  Icons.wifi_tethering,
                  helpTooltip:
                      'HOW TO SHARE:\n'
                      '1. Turn on sharing to broadcast live sim data over Wi-Fi.\n'
                      '2. On your phone, tablet, or Mac, open Concorde EFB > MONITOR.\n'
                      '3. Enter this PC address and pairing code.\n'
                      '4. Allow msfs_bridge on Private networks if prompted.',
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
              'Turn on to stream live Flight Monitor data to your phone, tablet, or Mac (same Wi-Fi).',
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
            const SizedBox(height: 8),
            _note(
              context,
              'Open MONITOR on your other device and enter the pairing code above.',
            ),
            const SizedBox(height: 10),
            // Android app is in internal testing -- opens the join steps.
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: AppColors.dark.bg,
                ),
                onPressed: () => showAndroidBetaDialog(context),
                icon: const Icon(Icons.android, size: 16),
                label: Text(
                  'DOWNLOAD FOR ANDROID TABLET / PHONE',
                  style: uiText(
                    context,
                    size: 10.5,
                    weight: FontWeight.w900,
                    color: AppColors.dark.bg,
                    letterSpacing: 0.8,
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

// ---------------------------------------------------------------------------

class _RemoteLink extends ConsumerStatefulWidget {
  const _RemoteLink();

  @override
  ConsumerState<_RemoteLink> createState() => _RemoteLinkState();
}

class _RemoteLinkState extends ConsumerState<_RemoteLink> {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(
            context,
            'CONNECT TO YOUR SIM PC',
            Icons.wifi_find,
            helpTooltip:
                'STEPS TO CONNECT:\n'
                '1. On your Windows PC running MSFS, open Concorde EFB.\n'
                '2. Go to MONITOR tab and turn on "Share".\n'
                '3. Both devices must be on the same Wi-Fi network.\n'
                '4. Enter the PC address and 6-digit pairing code here.',
            trailing: found.isEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 9,
                        height: 9,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SEARCHING LAN…',
                        style: uiText(
                          context,
                          size: 9.5,
                          weight: FontWeight.w700,
                          color: colors.textDim,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          if (found.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final b in found)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    label: Text(
                      '${b.name}  ${b.ip}',
                      style: uiText(
                        context,
                        size: 10.5,
                        weight: FontWeight.w800,
                        color: _host == b.ip
                            ? AppColors.dark.bg
                            : colors.textPrimary,
                      ),
                    ),
                    selected: _host == b.ip,
                    selectedColor: colors.accent,
                    onSelected: (_) => setState(() => _host = b.ip),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
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
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: EfbTextField(
                  key: ValueKey('code-$_code'),
                  label: 'PAIRING CODE',
                  initialValue: _code,
                  placeholder: '6 digits',
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _code = v.replaceAll(RegExp(r'\D'), '')),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: AppColors.dark.bg,
                    disabledBackgroundColor: colors.dividerStrong,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
              if (_editing && remote.isConfigured) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () async {
                      await ref.read(remoteBridgeProvider.notifier).forget();
                      if (mounted) setState(() => _editing = false);
                    },
                    child: Text(
                      'FORGET',
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
        ],
      ),
    );
  }
}
