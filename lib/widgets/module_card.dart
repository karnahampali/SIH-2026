import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/verification_result.dart';
import '../widgets/pramaan_theme.dart';

/// Expandable card showing per-module verification result.
class ModuleCard extends StatefulWidget {
  final ModuleResult module;
  final Duration animationDelay;

  const ModuleCard({
    super.key,
    required this.module,
    this.animationDelay = Duration.zero,
  });

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(widget.animationDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _moduleIcon {
    switch (widget.module.icon) {
      case 'document':
        return Icons.verified_user_outlined;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'face':
        return Icons.face;
      case 'database':
        return Icons.storage;
      case 'liveness':
        return Icons.remove_red_eye_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = widget.module.passed;
    final statusColor = passed ? PramaanColors.pass : PramaanColors.fail;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(_fadeIn),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: PramaanColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.15),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Icon(_moduleIcon, color: statusColor, size: 22),
              ),
              title: Text(
                widget.module.name,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PramaanColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Score chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      widget.module.scorePercent,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    passed ? Icons.check_circle : Icons.cancel,
                    color: statusColor,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: PramaanColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
              onExpansionChanged: (v) => setState(() => _expanded = v),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: statusColor.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      // Weight label
                      Row(
                        children: [
                          Icon(Icons.balance, size: 14, color: PramaanColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Weight in risk formula: ${widget.module.weight}%',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: PramaanColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Reason text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              passed ? Icons.info_outline : Icons.warning_amber,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.module.reason,
                                style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  color: PramaanColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Score bar
                      Row(
                        children: [
                          Text(
                            'Score: ',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: PramaanColors.textMuted,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: widget.module.score.clamp(0.0, 1.0),
                                backgroundColor: PramaanColors.surfaceLight,
                                valueColor: AlwaysStoppedAnimation(statusColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.module.scorePercent,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
