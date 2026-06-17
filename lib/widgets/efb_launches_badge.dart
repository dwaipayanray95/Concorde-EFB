import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/badge_provider.dart';
import '../core/ui_tokens.dart';

class EfbLaunchesBadge extends ConsumerWidget {
  const EfbLaunchesBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(visitorCountProvider);
    final numFormat = NumberFormat('#,###');

    return countAsync.when(
      data: (count) {
        if (count == 0) {
          return Text(
            'EFB Launches: Offline',
            style: GoogleFonts.plusJakartaSans(
              color: UiTokens.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF111A2B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
                child: Text(
                  'EFB LAUNCHES',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
                child: Text(
                  numFormat.format(count),
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Text(
        'Loading launches...',
        style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 12),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
