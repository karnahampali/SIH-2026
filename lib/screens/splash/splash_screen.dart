import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/pramaan_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _fadeCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _slideCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PramaanColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header / Logo ──────────────────────────────────────
            Expanded(
              flex: 5,
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 24,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          size: 54,
                          color: PramaanColors.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'PRAMAAN',
                        style: GoogleFonts.rajdhani(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 8.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 180,
                        height: 1.5,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'AI-Powered Document & Identity\nAuthentication System',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.6,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Role Select ────────────────────────────────────────
            Expanded(
              flex: 5,
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELECT YOUR ROLE',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            letterSpacing: 3.0,
                            color: PramaanColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RoleCard(
                          icon: Icons.document_scanner_outlined,
                          title: 'Start Screening',
                          subtitle: 'Automatically analyze ID and travel documents',
                          color: PramaanColors.primary,
                          onTap: () => context.pushNamed('checkpoint-scan'),
                        ),
                        const SizedBox(height: 20),
                        // Secondary links row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TextLink(
                              icon: Icons.bug_report_outlined,
                              label: 'Tamper Demo',
                              onTap: () => context.pushNamed('tamper'),
                            ),
                            _divider(),
                            _TextLink(
                              icon: Icons.history,
                              label: 'History',
                              onTap: () => context.pushNamed('history'),
                            ),
                            _divider(),
                            _TextLink(
                              icon: Icons.info_outline,
                              label: 'About',
                              onTap: () => context.pushNamed('about'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: Text(
                            'Smart India Hackathon 2026  ·  MHA / MEA',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: PramaanColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: PramaanColors.divider,
      );
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: PramaanColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: PramaanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TextLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: PramaanColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: PramaanColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
