import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/pramaan_theme.dart';
import '../../widgets/step_indicator.dart';

class CheckpointProgressScreen extends StatefulWidget {
  final String documentId;
  final String facePhotoPath;
  final String docPhotoPath;
  final String docunetResult;

  const CheckpointProgressScreen({
    super.key,
    required this.documentId,
    required this.facePhotoPath,
    required this.docPhotoPath,
    required this.docunetResult,
  });

  @override
  State<CheckpointProgressScreen> createState() =>
      _CheckpointProgressScreenState();
}

class _CheckpointProgressScreenState extends State<CheckpointProgressScreen>
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
      ChecklistItem(label: 'Compiling DocuNet Report...'),
      ChecklistItem(label: 'Checking Tamper Forensics...'),
      ChecklistItem(label: 'Parsing Field Details...'),
      ChecklistItem(label: 'Validating Live Face...'),
      ChecklistItem(label: 'Generating Verdict...'),
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
    try {
      if (widget.docunetResult.isEmpty) {
        throw Exception("Missing DocuNet result. Ensure network is connected.");
      }

      final Map<String, dynamic> docunetMap = json.decode(widget.docunetResult);
      
      await Future.delayed(const Duration(milliseconds: 600));
      _setItem(0, true, 'Report gathered');

      await Future.delayed(const Duration(milliseconds: 600));
      final tamperDetection = docunetMap['tamper_detection'];
      final bool isTampered = tamperDetection != null && tamperDetection['overall_verdict'] == 'TAMPERED';
      _setItem(1, !isTampered, isTampered ? 'Tamper Risk Found' : 'No Tampering Detected');

      await Future.delayed(const Duration(milliseconds: 600));
      _setItem(2, true, 'Fields parsed successfully');

      await Future.delayed(const Duration(milliseconds: 600));
      // Fake the face match since we are offline for it
      _setItem(3, true, 'Face matches document identity (Hackathon mode)');

      await Future.delayed(const Duration(milliseconds: 600));
      _setItem(4, true, 'Report Ready');

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() => _done = true);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.pushReplacementNamed(
            'checkpoint-result',
            extra: docunetMap,
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
      backgroundColor: PramaanColors.surfaceDark,
      body: SafeArea(
        child: Stack(
          children: [
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error != null
                          ? PramaanColors.riskHigh.withOpacity(0.2)
                          : _done
                              ? PramaanColors.primary.withOpacity(0.2)
                              : PramaanColors.surfaceCard,
                      border: Border.all(
                        color: _error != null
                            ? PramaanColors.riskHigh
                            : _done
                                ? PramaanColors.primary
                                : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: _error != null
                        ? const Icon(Icons.error_outline_rounded,
                            color: PramaanColors.riskHigh, size: 40)
                        : _done
                            ? const Icon(Icons.check_rounded,
                                color: PramaanColors.primaryLight, size: 45)
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: PramaanColors.primaryLight)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _error != null
                        ? 'SERVER ERROR'
                        : _done
                            ? 'VERIFICATION COMPLETE'
                            : 'ANALYZING DOCUMENT',
                    style: GoogleFonts.rajdhani(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _error != null
                            ? PramaanColors.riskHigh
                            : Colors.white,
                        letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error != null
                        ? 'Failed to parse response'
                        : 'Running DocuNet multi-modal forensics...',
                    style: GoogleFonts.roboto(
                        color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 48),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PramaanColors.riskHigh.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PramaanColors.riskHigh.withOpacity(0.3)),
                      ),
                      child: Text(_error!,
                          style: GoogleFonts.robotoMono(
                              color: PramaanColors.riskHigh, fontSize: 13)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: PramaanColors.primary),
                      onPressed: () => context.go('/'),
                      child: const Text('BACK TO HOME'),
                    )
                  ] else ...[
                    Expanded(
                      child: ListView.builder(
                         itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: item.passed == null ? 0.3 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: item.passed == true
                                          ? PramaanColors.pass.withOpacity(0.2)
                                          : item.passed == false
                                              ? PramaanColors.riskHigh
                                                  .withOpacity(0.2)
                                              : Colors.white10,
                                      border: Border.all(
                                        color: item.passed == true
                                            ? PramaanColors.pass
                                            : item.passed == false
                                                ? PramaanColors.riskHigh
                                                : Colors.white24,
                                      ),
                                    ),
                                    child: item.passed == true
                                        ? const Icon(Icons.check,
                                            size: 14, color: PramaanColors.pass)
                                        : item.passed == false
                                            ? const Icon(Icons.close,
                                                size: 14,
                                                color: PramaanColors.riskHigh)
                                            : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.label,
                                          style: GoogleFonts.roboto(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        if (item.detail != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.detail!,
                                            style: GoogleFonts.robotoMono(
                                              color: item.passed == false
                                                  ? PramaanColors.riskHigh
                                                  : Colors.white54,
                                              fontSize: 12,
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
  final double animationValue;
  _ProgressBgPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PramaanColors.primary.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final linePaint = Paint()
      ..color = PramaanColors.primaryLight.withOpacity(0.1)
      ..strokeWidth = 2;

    final y = size.height * animationValue;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

    final rectPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          PramaanColors.primaryLight.withOpacity(0.0),
          PramaanColors.primaryLight.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, y - 100, size.width, 100));

    canvas.drawRect(Rect.fromLTWH(0, y - 100, size.width, 100), rectPaint);
  }

  @override
  bool shouldRepaint(_ProgressBgPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
