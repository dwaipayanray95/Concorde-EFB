import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/efb_providers.dart';
import '../../widgets/efb_glass_container.dart';
import '../../widgets/entrance_fader.dart';
import '../../core/ui_tokens.dart';
import '../../data/checklist_data.dart';

/// Checklists tab: phase navigation panel on the left, checklist items with
/// live V-speed substitution on the right.
class ChecklistsTab extends ConsumerStatefulWidget {
  const ChecklistsTab({super.key});

  @override
  ConsumerState<ChecklistsTab> createState() => _ChecklistsTabState();
}

class _ChecklistsTabState extends ConsumerState<ChecklistsTab> {
  String selectedChecklistPhase = 'cold_dark';

  @override
  Widget build(BuildContext context) {
    return EntranceFader(
      key: const ValueKey('checklist-section'),
      delay: const Duration(milliseconds: 100),
      child: _buildChecklistsSection(ref),
    );
  }

  Widget _buildChecklistsSection(WidgetRef ref) {
    final checklistState = ref.watch(checklistProvider);
    final notifier = ref.read(checklistProvider.notifier);
    final landingSpeeds = ref.watch(landingSpeedsProvider);
    final takeoffSpeeds = ref.watch(takeoffSpeedsProvider);
    final simbriefLoaded = ref.watch(simbriefLoadedProvider);
    final vappSpeed = landingSpeeds['VAPP'];
    final vappStr = (simbriefLoaded && vappSpeed != null) ? '${vappSpeed.round()} KT' : 'VAPP';
    final v1 = takeoffSpeeds['V1'];
    final vr = takeoffSpeeds['VR'];
    final v2 = takeoffSpeeds['V2'];
    final vSpeedsStr = (simbriefLoaded && v1 != null && vr != null && v2 != null)
        ? 'V1:${v1.round()} VR:${vr.round()} V2:${v2.round()}'
        : 'V-Speeds';

    final checklistData = buildChecklistData(vSpeedsStr: vSpeedsStr, vappStr: vappStr);
    final currentItems = checklistData[selectedChecklistPhase] ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Navigation Panel
        Expanded(
          flex: 3,
          child: EfbGlassContainer(
            blur: 20,
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: checklistPhases.map((phase) {
                  final isSelected = selectedChecklistPhase == phase.id;
                  final phaseItems = checklistData[phase.id] ?? [];
                  final checkedCount = phaseItems.where((item) => checklistState[item.id] ?? false).length;
                  final totalCount = phaseItems.length;
                  final isCompleted = checkedCount == totalCount && totalCount > 0;

                  return InkWell(
                    onTap: () => setState(() => selectedChecklistPhase = phase.id),
                    borderRadius: BorderRadius.circular(12),
                    mouseCursor: SystemMouseCursors.click,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? UiTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? UiTokens.accent : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              phase.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : UiTokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? UiTokens.success.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted ? UiTokens.success : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Text(
                              '$checkedCount/$totalCount',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? UiTokens.success : UiTokens.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Right Checklist Panel
        Expanded(
          flex: 7,
          child: EfbGlassContainer(
            blur: 20,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        checklistPhases.firstWhere((p) => p.id == selectedChecklistPhase).name.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final ids = currentItems.map((item) => item.id).toList();
                          notifier.resetPhase(ids);
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: UiTokens.error),
                        label: Text(
                          'RESET PHASE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: UiTokens.error,
                            letterSpacing: 1,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentItems.length,
                      itemBuilder: (context, index) {
                        final item = currentItems[index];
                        final isChecked = checklistState[item.id] ?? false;

                        return InkWell(
                          onTap: () => notifier.toggle(item.id),
                          borderRadius: BorderRadius.circular(12),
                          mouseCursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isChecked ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value: isChecked,
                                      onChanged: (_) => notifier.toggle(item.id),
                                      activeColor: UiTokens.accent,
                                      checkColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.item,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isChecked ? UiTokens.textDim : Colors.white,
                                                decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            item.status,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isChecked ? UiTokens.textDim : UiTokens.accent,
                                              decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.note != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.note!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isChecked ? UiTokens.textDim.withValues(alpha: 0.5) : UiTokens.textDim,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
