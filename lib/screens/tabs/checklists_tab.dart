import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/efb_providers.dart';
import '../../features/flight_monitor/presentation/controllers/live_checklist_phase.dart';
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
  void initState() {
    super.initState();
    // Jump to the new phase whenever the live flight phase changes.
    ref.listenManual(liveChecklistPhaseProvider, (prev, next) {
      if (next != null && next != prev) {
        setState(() => selectedChecklistPhase = next);
      }
    }, fireImmediately: true);
  }

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
    // Live flight phase from the sim: the current phase is highlighted and
    // the others are greyed out (still tappable).
    final livePhase = ref.watch(liveChecklistPhaseProvider);
    final notifier = ref.read(checklistProvider.notifier);
    final landingSpeeds = ref.watch(landingSpeedsProvider);
    final takeoffSpeeds = ref.watch(takeoffSpeedsProvider);
    final simbriefLoaded = ref.watch(simbriefLoadedProvider);
    final vappStr = simbriefLoaded
        ? '${landingSpeeds.vapp.round()} KT'
        : 'VAPP';
    final vSpeedsStr = simbriefLoaded
        ? 'V1:${takeoffSpeeds.v1.round()} VR:${takeoffSpeeds.vr.round()} '
              'V2:${takeoffSpeeds.v2.round()}'
        : 'V-Speeds';

    final checklistData = buildChecklistData(
      vSpeedsStr: vSpeedsStr,
      vappStr: vappStr,
    );
    final currentItems = checklistData[selectedChecklistPhase] ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final leftPanel = Container(
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.dividerStrong.withValues(alpha: isDark ? 0.6 : 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: checklistPhases.map((phase) {
            final isSelected = selectedChecklistPhase == phase.id;
            final phaseItems = checklistData[phase.id] ?? [];
            final checkedCount = phaseItems
                .where((item) => checklistState[item.id] ?? false)
                .length;
            final totalCount = phaseItems.length;
            final isCompleted = checkedCount == totalCount && totalCount > 0;

            final activeText = const Color(0xFF101012);
            final isLive = livePhase == phase.id;
            final dim = livePhase != null && !isLive && !isSelected;

            return Opacity(
              opacity: dim ? 0.4 : 1,
              child: InkWell(
                onTap: () => setState(() => selectedChecklistPhase = phase.id),
                borderRadius: BorderRadius.circular(8),
                mouseCursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: colors.accent, width: 1.0)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isLive) ...[
                            Icon(
                              Icons.flight,
                              size: 13,
                              color: isSelected ? activeText : colors.success,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              phase.name,
                              style: uiText(
                                context,
                                size: 12.5,
                                weight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isSelected
                                    ? activeText
                                    : (isCompleted
                                          ? colors.textPrimary
                                          : colors.textSecondary),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isCompleted
                                        ? const Color(0xFF064E3B)
                                        : activeText.withValues(alpha: 0.15))
                                  : (isCompleted
                                        ? colors.successBg
                                        : colors.inputBg),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? (isCompleted
                                          ? const Color(0xFF059669)
                                          : activeText.withValues(alpha: 0.3))
                                    : (isCompleted
                                          ? colors.success.withValues(
                                              alpha: 0.4,
                                            )
                                          : colors.dividerStrong),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '$checkedCount/$totalCount',
                              style: uiText(
                                context,
                                size: 10,
                                weight: FontWeight.w900,
                                color: isSelected
                                    ? (isCompleted ? Colors.white : activeText)
                                    : (isCompleted
                                          ? colors.success
                                          : colors.textDim),
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
                          backgroundColor: isSelected
                              ? activeText.withValues(alpha: 0.2)
                              : colors.dividerStrong.withValues(alpha: 0.35),
                          valueColor: AlwaysStoppedAnimation(
                            isSelected
                                ? (isCompleted
                                      ? const Color(0xFF047857)
                                      : activeText)
                                : (isCompleted
                                      ? colors.success
                                      : colors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
    final rightPanel = Container(
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.dividerStrong.withValues(alpha: isDark ? 0.6 : 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Integrated Titlebar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141417) : const Color(0xFFEBEBEF),
              border: Border(
                bottom: BorderSide(
                  color: colors.dividerStrong.withValues(
                    alpha: isDark ? 0.5 : 0.7,
                  ),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Icon(Icons.playlist_add_check, size: 16, color: colors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    checklistPhases
                        .firstWhere((p) => p.id == selectedChecklistPhase)
                        .name
                        .toUpperCase(),
                    style: uiText(
                      context,
                      size: 12,
                      weight: FontWeight.w900,
                      color: colors.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    final ids = currentItems.map((item) => item.id).toList();
                    notifier.resetPhase(ids);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 13, color: colors.error),
                        const SizedBox(width: 5),
                        Text(
                          'RESET PHASE',
                          style: uiText(
                            context,
                            size: 10,
                            weight: FontWeight.w800,
                            color: colors.error,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? colors.successBg.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
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
                        const SizedBox(width: 4),
                        Text(
                          stepNo,
                          style: uiText(
                            context,
                            size: 11,
                            weight: FontWeight.bold,
                            color: colors.textDim,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ChecklistMark(
                          checked: isChecked,
                          onTap: () => notifier.toggle(item.id),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    item.item.toUpperCase(),
                                    style: uiText(
                                      context,
                                      size: 13,
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CustomPaint(
                                      size: const Size(double.infinity, 12),
                                      painter: _DotLeaderPainter(
                                        color: colors.dividerStrong.withValues(
                                          alpha: isChecked ? 0.2 : 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                                      borderRadius: BorderRadius.circular(4),
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
                                        size: 11,
                                        weight: FontWeight.bold,
                                        color: isChecked
                                            ? colors.textDim
                                            : colors.accent,
                                        letterSpacing: 0.4,
                                        decoration: isChecked
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.note != null) ...[
                                const SizedBox(height: 5),
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: leftPanel),
              const SizedBox(width: 16),
              Expanded(flex: 7, child: rightPanel),
            ],
          );
        }
        // Phones / narrow windows: phases become a horizontal strip so the
        // checklist items get the full width.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: checklistPhases.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final phase = checklistPhases[i];
                  final isSelected = selectedChecklistPhase == phase.id;
                  final phaseItems = checklistData[phase.id] ?? [];
                  final done = phaseItems
                      .where((item) => checklistState[item.id] ?? false)
                      .length;
                  final isLive = livePhase == phase.id;
                  final dim = livePhase != null && !isLive && !isSelected;
                  return Opacity(
                    opacity: dim ? 0.4 : 1,
                    child: InkWell(
                      onTap: () =>
                          setState(() => selectedChecklistPhase = phase.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accent : colors.resultsBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLive
                                ? colors.success
                                : (isSelected
                                      ? colors.accent
                                      : colors.dividerStrong),
                            width: isLive ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          '${isLive ? '● ' : ''}${phase.name.toUpperCase()}  $done/${phaseItems.length}',
                          style: uiText(
                            context,
                            size: 10.5,
                            weight: FontWeight.w800,
                            color: isSelected
                                ? AppColors.dark.bg
                                : colors.textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: rightPanel),
          ],
        );
      },
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

class _DotLeaderPainter extends CustomPainter {
  final Color color;

  const _DotLeaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const spacing = 5.0;
    final centerY = size.height / 2;
    double currentX = 2;

    while (currentX < size.width - 2) {
      canvas.drawCircle(Offset(currentX, centerY), 0.75, paint);
      currentX += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _DotLeaderPainter oldDelegate) =>
      oldDelegate.color != color;
}
