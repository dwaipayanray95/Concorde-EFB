import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/efb_providers.dart';
import '../../widgets/efb_flat_card.dart';
import '../../widgets/entrance_fader.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
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
      child: _buildChecklistsSection(context, ref),
    );
  }

  Widget _buildChecklistsSection(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final checklistState = ref.watch(checklistProvider);
    final notifier = ref.read(checklistProvider.notifier);
    final landingSpeeds = ref.watch(landingSpeedsProvider);
    final takeoffSpeeds = ref.watch(takeoffSpeedsProvider);
    final simbriefLoaded = ref.watch(simbriefLoadedProvider);
    final vappSpeed = landingSpeeds['VAPP'];
    final vappStr = (simbriefLoaded && vappSpeed != null)
        ? '${vappSpeed.round()} KT'
        : 'VAPP';
    final v1 = takeoffSpeeds['V1'];
    final vr = takeoffSpeeds['VR'];
    final v2 = takeoffSpeeds['V2'];
    final vSpeedsStr =
        (simbriefLoaded && v1 != null && vr != null && v2 != null)
        ? 'V1:${v1.round()} VR:${vr.round()} V2:${v2.round()}'
        : 'V-Speeds';

    final checklistData = buildChecklistData(
      vSpeedsStr: vSpeedsStr,
      vappStr: vappStr,
    );
    final currentItems = checklistData[selectedChecklistPhase] ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Navigation Panel
        Expanded(
          flex: 3,
          child: EfbFlatCard(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: checklistPhases.map((phase) {
                  final isSelected = selectedChecklistPhase == phase.id;
                  final phaseItems = checklistData[phase.id] ?? [];
                  final checkedCount = phaseItems
                      .where((item) => checklistState[item.id] ?? false)
                      .length;
                  final totalCount = phaseItems.length;
                  final isCompleted =
                      checkedCount == totalCount && totalCount > 0;

                  return InkWell(
                    onTap: () =>
                        setState(() => selectedChecklistPhase = phase.id),
                    borderRadius: BorderRadius.circular(12),
                    mouseCursor: SystemMouseCursors.click,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colors.accent
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  phase.name,
                                  style: uiText(
                                    context,
                                    size: 13,
                                    weight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colors.accent
                                        : colors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? colors.successBg
                                      : colors.inputBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCompleted
                                        ? colors.success.withValues(alpha: 0.3)
                                        : colors.dividerStrong,
                                  ),
                                ),
                                child: Text(
                                  '$checkedCount/$totalCount',
                                  style: uiText(
                                    context,
                                    size: 10,
                                    weight: FontWeight.bold,
                                    color: isCompleted
                                        ? colors.success
                                        : colors.textDim,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: totalCount == 0
                                  ? 0
                                  : checkedCount / totalCount,
                              minHeight: 3,
                              backgroundColor: colors.dividerStrong.withValues(
                                alpha: 0.4,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                isCompleted ? colors.success : colors.accent,
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
          child: EfbFlatCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      checklistPhases
                          .firstWhere((p) => p.id == selectedChecklistPhase)
                          .name
                          .toUpperCase(),
                      style: uiText(
                        context,
                        size: 16,
                        weight: FontWeight.w900,
                        color: colors.textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final ids = currentItems
                            .map((item) => item.id)
                            .toList();
                        notifier.resetPhase(ids);
                      },
                      icon: Icon(Icons.refresh, size: 16, color: colors.error),
                      label: Text(
                        'RESET PHASE',
                        style: uiText(
                          context,
                          size: 12,
                          weight: FontWeight.bold,
                          color: colors.error,
                          letterSpacing: 1,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: colors.divider),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: currentItems.length,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: CustomPaint(
                        size: const Size(double.infinity, 1),
                        painter: _DashedLinePainter(color: colors.divider),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final item = currentItems[index];
                      final isChecked = checklistState[item.id] ?? false;
                      final stepNo = (index + 1).toString().padLeft(2, '0');

                      return InkWell(
                        onTap: () => notifier.toggle(item.id),
                        mouseCursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isChecked
                                ? colors.successBg.withValues(alpha: 0.35)
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isChecked
                                    ? colors.success
                                    : colors.accent.withValues(alpha: 0.5),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                stepNo,
                                style: uiText(
                                  context,
                                  size: 12,
                                  weight: FontWeight.bold,
                                  color: colors.textDim,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _ChecklistMark(
                                checked: isChecked,
                                onTap: () => notifier.toggle(item.id),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.item.toUpperCase(),
                                            style: uiText(
                                              context,
                                              size: 14,
                                              weight: FontWeight.w700,
                                              color: isChecked
                                                  ? colors.textDim
                                                  : colors.textPrimary,
                                              letterSpacing: 0.5,
                                              decoration: isChecked
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isChecked
                                                ? Colors.transparent
                                                : colors.accent.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: isChecked
                                                  ? colors.dividerStrong
                                                  : colors.accent.withValues(
                                                      alpha: 0.4,
                                                    ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: uiText(
                                              context,
                                              size: 12,
                                              weight: FontWeight.bold,
                                              color: isChecked
                                                  ? colors.textDim
                                                  : colors.accent,
                                              letterSpacing: 0.5,
                                              decoration: isChecked
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.note != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '// ${item.note!}',
                                        style: uiText(
                                          context,
                                          size: 11,
                                          weight: FontWeight.w500,
                                          color: colors.textDim,
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
      ],
    );
  }
}

/// Aviation-style checklist mark: an empty bracketed box that fills with a
/// solid accent square and checkmark once actioned, echoing paper checklist
/// strips rather than a stock Material checkbox.
class _ChecklistMark extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const _ChecklistMark({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: checked ? colors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: checked ? colors.success : colors.dividerStrong,
            width: 1.5,
          ),
        ),
        child: checked
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Thin dashed rule used between checklist rows to mimic a torn paper strip.
class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
