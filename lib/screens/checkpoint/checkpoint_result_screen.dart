import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/verification_result.dart';
import '../../providers.dart';
import '../../widgets/module_card.dart';
import '../../widgets/pramaan_theme.dart';
import '../../widgets/risk_banner.dart';

class CheckpointResultScreen extends ConsumerStatefulWidget {
  final dynamic result;
  const CheckpointResultScreen({super.key, required this.result});

  @override
  ConsumerState<CheckpointResultScreen> createState() =>
      _CheckpointResultScreenState();
}

class _CheckpointResultScreenState
    extends ConsumerState<CheckpointResultScreen> {
  VerificationResult? _result;
  bool _actionTaken = false;

  @override
  void initState() {
    super.initState();
    if (widget.result is VerificationResult) {
      _result = widget.result as VerificationResult;
    }
  }

  Future<void> _approve() async {
    if (_result == null) return;
    await ref.read(verificationServiceProvider).saveVerificationResult(
          _result!,
          'APPROVED',
        );
    setState(() => _actionTaken = true);
    _showActionSnackbar('APPROVED', PramaanColors.riskLow);
  }

  Future<void> _flagForReview() async {
    if (_result == null) return;
    await ref.read(verificationServiceProvider).saveVerificationResult(
          _result!,
          'FLAGGED',
        );
    setState(() => _actionTaken = true);
    _showActionSnackbar('FLAGGED FOR MANUAL REVIEW', PramaanColors.riskHigh);
  }

  void _showActionSnackbar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.goNamed('splash');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('VERIFICATION RESULT')),
        body: Center(
          child: Text(
            'No result data',
            style: GoogleFonts.roboto(color: PramaanColors.textMuted),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PramaanColors.navyDark,
      appBar: AppBar(
        title: const Text('VERIFICATION RESULT'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.goNamed('splash'),
            child: Text(
              'HOME',
              style: GoogleFonts.rajdhani(
                color: PramaanColors.steelBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: RiskBanner(
              riskLevel: _result!.riskLevel,
              riskScore: _result!.riskScore,
            ),
          ),

          // Document info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PramaanColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PramaanColors.divider),
              ),
              child: Row(
                children: [
                  if (_result!.liveFacePhotoPath.isNotEmpty &&
                      File(_result!.liveFacePhotoPath).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_result!.liveFacePhotoPath),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: PramaanColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person, color: PramaanColors.textMuted),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _result!.documentName,
                          style: GoogleFonts.rajdhani(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PramaanColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_result!.documentType} · ${_result!.documentId.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: PramaanColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _result!.verifiedAt.toLocal().toString().substring(0, 19),
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: PramaanColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
            child: Text(
              'VERIFICATION BREAKDOWN',
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: PramaanColors.steelBlue,
              ),
            ),
          ),

          // Module cards
          ..._result!.modules.asMap().entries.map(
            (e) => ModuleCard(
              module: e.value,
              animationDelay: Duration(milliseconds: e.key * 100),
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          if (!_actionTaken)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PramaanColors.riskHigh,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _flagForReview,
                          icon: const Icon(Icons.flag),
                          label: const Text('FLAG FOR REVIEW'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PramaanColors.riskLow,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _approve,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('APPROVE'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.pushNamed('history'),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('VIEW SCAN HISTORY'),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
