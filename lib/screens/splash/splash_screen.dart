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
  late AnimationController _logoController;
  late AnimationController _contentController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);

    _contentOpacity = CurvedAnimation(parent: _contentController, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentController, curve: Curves.easeOut));

    _logoController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _contentController.forward();
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PramaanColors.navyDark,
              PramaanColors.navyPrimary,
              Color(0xFF1E3D6E),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header / logo area
              Expanded(
                flex: 5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hexagonal shield logo
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoOpacity,
                          child: _ShieldLogo(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _logoOpacity,
                        child: Column(
                          children: [
                            Text(
                              'PRAMAAN',
                              style: GoogleFonts.rajdhani(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 8.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 200,
                              height: 2,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    PramaanColors.steelBlue,
                                    PramaanColors.accent,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'AI-Powered Multi-Layer Document\n& Identity Authentication',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: PramaanColors.textSecondary,
                                height: 1.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Role select buttons
              Expanded(
                flex: 4,
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SELECT YOUR ROLE',
                            style: GoogleFonts.rajdhani(
                              fontSize: 13,
                              letterSpacing: 3.0,
                              color: PramaanColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _RoleButton(
                            icon: Icons.badge_outlined,
                            title: 'Issuing Authority',
                            subtitle: 'Issue & sign identity documents',
                            color: PramaanColors.steelBlue,
                            onTap: () => context.pushNamed('issuance-form'),
                          ),
                          const SizedBox(height: 16),
                          _RoleButton(
                            icon: Icons.security,
                            title: 'Checkpoint Officer',
                            subtitle: 'Verify & authenticate documents',
                            color: const Color(0xFF2D7A4F),
                            onTap: () => context.pushNamed('checkpoint-scan'),
                          ),
                          const SizedBox(height: 32),
                          // Secondary nav
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _NavLink(
                                icon: Icons.shield_outlined,
                                label: 'Tamper Demo',
                                onTap: () => context.pushNamed('tamper'),
                              ),
                              const SizedBox(width: 24),
                              _NavLink(
                                icon: Icons.history,
                                label: 'History',
                                onTap: () => context.pushNamed('history'),
                              ),
                              const SizedBox(width: 24),
                              _NavLink(
                                icon: Icons.info_outline,
                                label: 'About',
                                onTap: () => context.pushNamed('about'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Smart India Hackathon 2024 · Ministry of External Affairs',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: PramaanColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                PramaanColors.steelBlue.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Shield container
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PramaanColors.steelBlue, PramaanColors.navyPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: PramaanColors.steelBlue.withOpacity(0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: PramaanColors.steelBlue.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.shield,
            size: 60,
            color: Colors.white,
          ),
        ),
        // Badge overlay
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PramaanColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: PramaanColors.navyDark, width: 2),
            ),
            child: const Icon(Icons.verified, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _RoleButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_RoleButton> createState() => _RoleButtonState();
}

class _RoleButtonState extends State<_RoleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color.withOpacity(0.25),
                widget.color.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withOpacity(0.4)),
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: PramaanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: widget.color.withOpacity(0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: PramaanColors.textMuted, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 11,
              color: PramaanColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
