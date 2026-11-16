import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../data/services/lan_link.dart';
import '../../controllers/telemetry_provider.dart';

/// Inline Wi-Fi link controls for the sim PC link, displayed in line with the
/// Flight Monitor status toolbar.
///  - Windows desktop: toggle sharing, show this PC's IP + pairing code.
///  - Remote clients (Mac, Android, iOS): address & pairing code inputs + connect button.
class WifiLinkCard extends ConsumerWidget {
  const WifiLinkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isRemoteClientPlatform) return const _RemoteLink();
    if (isWindowsDesktop) return const _DesktopShare();
    return const SizedBox.shrink();
  }
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ? Tutorial Help Tooltip
        Tooltip(
          message:
              'HOW TO SHARE:\n'
              '1. Turn on sharing to broadcast live sim data over Wi-Fi.\n'
              '2. On your phone, tablet, or Mac, open Concorde EFB > MONITOR.\n'
              '3. Enter this PC address and pairing code.\n'
              '4. Allow msfs_bridge on Private networks if prompted.',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                Icons.help_outline_rounded,
                size: 15,
                color: colors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.wifi_tethering,
          size: 14,
          color: share.enabled ? colors.accent : colors.textDim,
        ),
        const SizedBox(width: 6),
        Text(
          'SHARE TO PHONE / TABLET / MAC',
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.w800,
            color: share.enabled ? colors.textPrimary : colors.textDim,
            letterSpacing: 0.6,
          ),
        ),
        if (share.enabled) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.resultsBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.dividerStrong, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ips.isEmpty ? 'NO NETWORK' : ips.first,
                  style: uiText(
                    context,
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CODE: $code',
                  style: uiText(
                    context,
                    size: 10.5,
                    weight: FontWeight.w900,
                    color: colors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () =>
                      ref.read(lanShareProvider.notifier).regenerateCode(),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.refresh, size: 12, color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: share.enabled,
            activeThumbColor: colors.accent,
            onChanged: (v) => ref.read(lanShareProvider.notifier).setEnabled(v),
          ),
        ),
      ],
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
  late final TextEditingController _hostController;
  late final TextEditingController _codeController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final remote = ref.read(remoteBridgeProvider);
    _hostController = TextEditingController(text: remote.host);
    _codeController = TextEditingController(text: remote.code);
    _hostController.addListener(_onInputChanged);
    _codeController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hostController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remote = ref.watch(remoteBridgeProvider);
    final monitor = ref.watch(flightMonitorProvider);
    final live = monitor.isConnected;
    final reachable = monitor.bridge.socketConnected;

    // Paired and connected (or reachable): compact inline status + change button.
    if (remote.isConfigured && !_editing) {
      final (text, color) = monitor.bridge.pairingRejected
          ? ('PAIRING CODE REJECTED', colors.error)
          : live
          ? ('FROM ${remote.host}', colors.success)
          : reachable
          ? ('CONNECTED TO ${remote.host}', colors.accent)
          : ('CANNOT REACH ${remote.host}', colors.accent);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: uiText(
              context,
              size: 10.5,
              weight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() {
              _editing = true;
              _hostController.text = remote.host;
              _codeController.text = remote.code;
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
      );
    }

    final found = ref.watch(discoveredBridgesProvider).value ?? const [];
    final canConnect =
        _hostController.text.trim().isNotEmpty &&
        RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim());

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ? Tutorial Help Tooltip
        Tooltip(
          message:
              'STEPS TO CONNECT:\n'
              '1. On your Windows PC running MSFS, open Concorde EFB.\n'
              '2. Go to MONITOR tab and turn on "Share".\n'
              '3. Ensure both devices are on the same Wi-Fi network.\n'
              '4. Enter the PC address and 6-digit pairing code here.',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                Icons.help_outline_rounded,
                size: 15,
                color: colors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Auto-discovered PCs
        if (found.isNotEmpty) ...[
          for (final b in found)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                label: Text(
                  '${b.name}  ${b.ip}',
                  style: uiText(
                    context,
                    size: 10,
                    weight: FontWeight.w800,
                    color: _hostController.text == b.ip
                        ? AppColors.dark.bg
                        : colors.textPrimary,
                  ),
                ),
                backgroundColor: _hostController.text == b.ip
                    ? colors.accent
                    : colors.surface,
                onPressed: () {
                  _hostController.text = b.ip;
                  setState(() {});
                },
              ),
            ),
        ] else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'SEARCHING LAN…',
                style: uiText(
                  context,
                  size: 9.5,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],

        // IP Address input
        SizedBox(
          width: 125,
          height: 30,
          child: TextField(
            controller: _hostController,
            style: uiText(
              context,
              size: 10.5,
              weight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            cursorColor: colors.accent,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              hintText: 'PC ADDRESS',
              hintStyle: uiText(
                context,
                size: 9.5,
                weight: FontWeight.w600,
                color: colors.textDim,
              ),
              filled: true,
              fillColor: colors.resultsBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colors.dividerStrong,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colors.dividerStrong,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colors.accent,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Pairing code input
        SizedBox(
          width: 85,
          height: 30,
          child: TextField(
            controller: _codeController,
            style: uiText(
              context,
              size: 10.5,
              weight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            cursorColor: colors.accent,
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final digits = v.replaceAll(RegExp(r'\D'), '');
              if (digits != v) {
                _codeController.text = digits;
                _codeController.selection = TextSelection.collapsed(
                  offset: digits.length,
                );
              }
            },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              hintText: 'PAIRING CODE',
              hintStyle: uiText(
                context,
                size: 9,
                weight: FontWeight.w600,
                color: colors.textDim,
              ),
              filled: true,
              fillColor: colors.resultsBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colors.dividerStrong,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colors.dividerStrong,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colors.accent,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Connect button
        SizedBox(
          height: 30,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: AppColors.dark.bg,
              disabledBackgroundColor: colors.dividerStrong,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            onPressed: canConnect
                ? () async {
                    await ref
                        .read(remoteBridgeProvider.notifier)
                        .connect(
                          _hostController.text,
                          _codeController.text,
                        );
                    if (mounted) setState(() => _editing = false);
                  }
                : null,
            child: Text(
              'CONNECT',
              style: uiText(
                context,
                size: 10,
                weight: FontWeight.w900,
                color: canConnect ? AppColors.dark.bg : colors.textDim,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),

        // Forget button if editing
        if (_editing && remote.isConfigured) ...[
          const SizedBox(width: 6),
          SizedBox(
            height: 30,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                await ref.read(remoteBridgeProvider.notifier).forget();
                if (mounted) {
                  setState(() {
                    _editing = false;
                    _hostController.clear();
                    _codeController.clear();
                  });
                }
              },
              child: Text(
                'FORGET',
                style: uiText(
                  context,
                  size: 9.5,
                  weight: FontWeight.w800,
                  color: colors.error,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
