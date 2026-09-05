import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/pramaan_theme.dart';

/// Big color-coded risk status banner for the results screen.
class RiskBanner extends StatefulWidget {
  final RiskLevel riskLevel;
  final double riskScore;

  const RiskBanner({
    super.key,
    required this.riskLevel,
    required this.riskScore,
  });

  @override
  State<RiskBanner> createState() => _RiskBannerState();
}

class _RiskBannerState extends State<RiskBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.riskLevel.color;
    final isDangerous = widget.riskLevel == RiskLevel.high ||
        widget.riskLevel == RiskLevel.critical;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: isDangerous ? _pulse.value : 1.0,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.85),
              color.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shield icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: Icon(
                widget.riskLevel.icon,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Risk label
            Text(
              widget.riskLevel.label,
              style: GoogleFonts.rajdhani(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 8),
            // Risk score
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widget.riskScore),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return Text(
                  'Risk Score: ${value.toStringAsFixed(0)} / 100',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Score progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.riskScore / 100),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOut,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 8,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
