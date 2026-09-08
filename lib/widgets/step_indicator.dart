import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/pramaan_theme.dart';

/// Animated vertical step indicator for the issuance processing screen.
class StepIndicator extends StatefulWidget {
  final List<String> steps;
  final int currentStep; // 0-indexed, -1 = none started
  final bool completed;

  const StepIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
    this.completed = false,
  });

  @override
  State<StepIndicator> createState() => _StepIndicatorState();
}

class _StepIndicatorState extends State<StepIndicator> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.steps.length, (i) {
        final isDone = widget.completed || i < widget.currentStep;
        final isActive = i == widget.currentStep && !widget.completed;
        final isPending = !widget.completed && i > widget.currentStep;

        return _StepRow(
          label: widget.steps[i],
          isDone: isDone,
          isActive: isActive,
          isPending: isPending,
          isLast: i == widget.steps.length - 1,
        );
      }),
    );
  }
}

class _StepRow extends StatefulWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isPending;
  final bool isLast;

  const _StepRow({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isPending,
    required this.isLast,
  });

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isActive) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StepRow old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isActive && old.isActive) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Widget dotChild;

    if (widget.isDone) {
      dotColor = PramaanColors.pass;
      dotChild = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (widget.isActive) {
      dotColor = PramaanColors.primary;
      dotChild = AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.5 + _pulse.value * 0.5),
          ),
        ),
      );
    } else {
      dotColor = PramaanColors.surfaceLight;
      dotChild = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PramaanColors.divider,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: widget.isActive || widget.isDone
                    ? [BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 10)]
                    : null,
              ),
              child: Center(child: dotChild),
            ),
            if (!widget.isLast)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 2,
                height: 40,
                color: widget.isDone ? PramaanColors.pass : PramaanColors.divider,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.roboto(
                fontSize: 15,
                color: widget.isDone
                    ? PramaanColors.textPrimary
                    : widget.isActive
                        ? PramaanColors.primary
                        : PramaanColors.textMuted,
                fontWeight: widget.isActive || widget.isDone
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated checklist for the checkpoint verification progress screen.
class VerificationChecklist extends StatefulWidget {
  final List<ChecklistItem> items;

  const VerificationChecklist({super.key, required this.items});

  @override
  State<VerificationChecklist> createState() => _VerificationChecklistState();
}

class ChecklistItem {
  final String label;
  final bool? passed; // null = in progress
  final String? detail;

  ChecklistItem({required this.label, this.passed, this.detail});
}

class _VerificationChecklistState extends State<VerificationChecklist> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.items.asMap().entries.map((entry) {
        return _ChecklistRow(
          item: entry.value,
          animDelay: Duration(milliseconds: entry.key * 150),
        );
      }).toList(),
    );
  }
}

class _ChecklistRow extends StatefulWidget {
  final ChecklistItem item;
  final Duration animDelay;

  const _ChecklistRow({required this.item, required this.animDelay});

  @override
  State<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends State<_ChecklistRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(-0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.animDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passed = widget.item.passed;
    Color color;
    Widget icon;

    if (passed == null) {
      color = PramaanColors.primary;
      icon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: PramaanColors.primary,
        ),
      );
    } else if (passed) {
      color = PramaanColors.pass;
      icon = Icon(Icons.check_circle, color: PramaanColors.pass, size: 22);
    } else {
      color = PramaanColors.fail;
      icon = Icon(Icons.cancel, color: PramaanColors.fail, size: 22);
    }

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.label,
                      style: GoogleFonts.rajdhani(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PramaanColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.item.detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.item.detail!,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
