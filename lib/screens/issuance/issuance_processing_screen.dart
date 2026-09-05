import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/issued_document.dart';
import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';
import '../../widgets/step_indicator.dart';

class IssuanceProcessingScreen extends ConsumerStatefulWidget {
  const IssuanceProcessingScreen({super.key});

  @override
  ConsumerState<IssuanceProcessingScreen> createState() =>
      _IssuanceProcessingScreenState();
}

class _IssuanceProcessingScreenState
    extends ConsumerState<IssuanceProcessingScreen>
    with SingleTickerProviderStateMixin {
  static const _steps = [
    'Generating photo fingerprint…',
    'Combining with document data…',
    'Signing with Ed25519 issuer key…',
    'Encoding QR code…',
  ];

  int _currentStep = 0;
  bool _completed = false;
  bool _error = false;
  String _errorMsg = '';

  late AnimationController _bgCtrl;
  late Animation<double> _bgRotate;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _bgRotate = Tween<double>(begin: 0, end: 1).animate(_bgCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _runPipeline() async {
    final form = ref.read(issuanceFormProvider);
    final verService = ref.read(verificationServiceProvider);

    try {
      int step = 0;

      final doc = await verService.issueDocument(
        name: form.name,
        dob: form.dob,
        idNumber: form.idNumber,
        nationality: form.nationality,
        expiry: form.expiry,
        docType: form.docType,
        photo: File(form.photoPath!),
        onStep: (label) async {
          if (mounted) setState(() => _currentStep = step);
          await Future.delayed(const Duration(milliseconds: 700));
          step++;
        },
      );

      if (mounted) {
        setState(() {
          _currentStep = _steps.length;
          _completed = true;
        });

        // Auto-navigate after a short celebration delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.pushReplacementNamed(
            'issuance-result',
            queryParameters: {'docId': doc.id},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PramaanColors.navyDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated bg
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgRotate,
                builder: (_, __) => CustomPaint(
                  painter: _RadarPainter(_bgRotate.value),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Animated shield
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _completed
                          ? PramaanColors.pass.withOpacity(0.2)
                          : PramaanColors.steelBlue.withOpacity(0.15),
                      border: Border.all(
                        color: _completed
                            ? PramaanColors.pass
                            : PramaanColors.steelBlue,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_completed
                                  ? PramaanColors.pass
                                  : PramaanColors.steelBlue)
                              .withOpacity(0.3),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Icon(
                      _completed ? Icons.verified : Icons.security,
                      size: 52,
                      color: _completed
                          ? PramaanColors.pass
                          : PramaanColors.steelBlue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _completed
                        ? 'DOCUMENT ISSUED!'
                        : 'PROCESSING DOCUMENT',
                    style: GoogleFonts.rajdhani(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: PramaanColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _completed
                        ? 'Cryptographic signature generated successfully'
                        : 'Please wait while the document is being secured',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: PramaanColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Step indicator
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: PramaanColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: PramaanColors.divider),
                    ),
                    child: StepIndicator(
                      steps: _steps,
                      currentStep: _currentStep,
                      completed: _completed,
                    ),
                  ),

                  if (_error) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PramaanColors.fail.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PramaanColors.fail.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Error: $_errorMsg',
                        style: GoogleFonts.roboto(
                          color: PramaanColors.fail,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('GO BACK'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 0.7;
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      paint.color =
          PramaanColors.steelBlue.withOpacity(0.06 * (5 - i));
      paint.strokeWidth = 1;
      canvas.drawCircle(center, maxRadius * i / 4, paint);
    }

    // Sweep line
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 0.8,
        colors: [
          PramaanColors.steelBlue.withOpacity(0.4),
          Colors.transparent,
        ],
        transform: GradientRotation(progress * 2 * 3.14159),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}
