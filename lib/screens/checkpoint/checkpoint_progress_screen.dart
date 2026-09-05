import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/verification_result.dart';
import '../../providers.dart';
import '../../services/verification_service.dart';
import '../../widgets/pramaan_theme.dart';
import '../../widgets/step_indicator.dart';

class CheckpointProgressScreen extends ConsumerStatefulWidget {
  final String documentId;
  final String facePhotoPath;
  final String? tamperType;

  const CheckpointProgressScreen({
    super.key,
    required this.documentId,
    required this.facePhotoPath,
    this.tamperType,
  });

  @override
  ConsumerState<CheckpointProgressScreen> createState() =>
      _CheckpointProgressScreenState();
}

class _CheckpointProgressScreenState
    extends ConsumerState<CheckpointProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  final List<ChecklistItem> _items = [];
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _bgAnim = Tween<double>(begin: 0, end: 1).animate(_bgCtrl);

    _initItems();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runVerification());
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  void _initItems() {
    _items.addAll([
      ChecklistItem(label: 'OCR / Field Extraction'),
      ChecklistItem(label: 'Document Signature Check'),
      ChecklistItem(label: 'Photo Fingerprint Match'),
      ChecklistItem(label: 'Live Face Match'),
      ChecklistItem(label: 'Liveness Check'),
      ChecklistItem(label: 'Identity History Cross-Check'),
    ]);
  }

  void _setItem(int index, bool passed, String? detail) {
    if (!mounted) return;
    setState(() {
      _items[index] = ChecklistItem(
        label: _items[index].label,
        passed: passed,
        detail: detail,
      );
    });
  }

  Future<void> _runVerification() async {
    final verService = ref.read(verificationServiceProvider);

    // Build tamper spec if needed
    TamperSpec? tamperSpec;
    if (widget.tamperType == 'editDob') {
      tamperSpec = TamperSpec.editDob();
    } else if (widget.tamperType == 'swapPhoto') {
      tamperSpec = TamperSpec.swapPhoto();
    } else if (widget.tamperType == 'clone') {
      tamperSpec = TamperSpec.cloneDocument();
    }

    try {
      // Step 0: OCR — always passes in demo
      await Future.delayed(const Duration(milliseconds: 500));
      _setItem(0, true, 'All fields extracted successfully');

      VerificationResult? result;

      result = await verService.verifyDocument(
        documentId: widget.documentId,
        livePhoto: File(widget.facePhotoPath),
        tamperSpec: tamperSpec,
        onStep: (step) async {
          // steps come in order: sig, photo, face, db, liveness
          if (step.contains('signature')) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        },
      );

      // Reveal results in sequence
      await Future.delayed(const Duration(milliseconds: 300));
      _setItem(
        1,
        result.docIntegrityScore >= 0.5,
        result.docIntegrityScore >= 0.5 ? 'Signature valid ✓' : 'Signature FAILED ✗',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      _setItem(
        2,
        result.photoMatchScore >= 0.5,
        'Similarity: ${(result.photoMatchScore * 100).toStringAsFixed(0)}%',
      );

      await Future.delayed(const Duration(milliseconds: 600));
      _setItem(
        3,
        result.faceMatchScore >= 0.60,
        'Match score: ${(result.faceMatchScore * 100).toStringAsFixed(0)}%',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      _setItem(
        4,
        result.livenessScore >= 0.5,
        result.livenessScore >= 0.5 ? 'Live subject confirmed' : 'Liveness FAILED',
      );

      await Future.delayed(const Duration(milliseconds: 400));
      _setItem(
        5,
        result.dbStatusScore >= 0.5,
        result.dbStatusScore >= 0.8
            ? 'No anomalies in history'
            : 'History anomaly detected',
      );

      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() => _done = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.pushReplacementNamed(
            'checkpoint-result',
            extra: result,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PramaanColors.navyDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Background animation
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgAnim,
                builder: (_, __) => CustomPaint(
                  painter: _ProgressBgPainter(_bgAnim.value),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Header icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _done
                          ? PramaanColors.steelBlue.withOpacity(0.2)
                          : PramaanColors.surfaceCard,
                      border: Border.all(
                        color: _done
                            ? PramaanColors.steelBlue
                            : PramaanColors.divider,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PramaanColors.steelBlue.withOpacity(0.25),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      _done ? Icons.assessment : Icons.verified_user_outlined,
                      size: 46,
                      color: _done
                          ? PramaanColors.steelBlue
                          : PramaanColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _done ? 'ANALYSIS COMPLETE' : 'VERIFYING DOCUMENT',
                    style: GoogleFonts.rajdhani(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: PramaanColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _done
                        ? 'Results ready — generating report'
                        : 'Running multi-layer authentication checks',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: PramaanColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Checklist
                  Expanded(
                    child: SingleChildScrollView(
                      child: VerificationChecklist(items: _items),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PramaanColors.fail.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: PramaanColors.fail.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Verification error: $_error',
                        style: GoogleFonts.roboto(
                          color: PramaanColors.fail,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.goNamed('splash'),
                      child: const Text('RETURN HOME'),
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

class _ProgressBgPainter extends CustomPainter {
  final double progress;
  _ProgressBgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.3);
    const maxR = 180.0;
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      final r = maxR * i / 3;
      paint.color = PramaanColors.steelBlue.withOpacity(0.04 * (4 - i));
      paint.strokeWidth = 1;
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(_ProgressBgPainter old) => false;
}
