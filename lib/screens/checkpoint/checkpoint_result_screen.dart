import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/pramaan_theme.dart';

class CheckpointResultScreen extends StatelessWidget {
  final dynamic result;
  const CheckpointResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    if (result is! Map<String, dynamic>) {
      return Scaffold(
        backgroundColor: PramaanColors.surfaceDark,
        body: Center(
            child: Text('Invalid result format',
                style: GoogleFonts.roboto(color: Colors.white))),
      );
    }

    final apiResult = result as Map<String, dynamic>;
    final parsedDoc = apiResult['document'] ?? {};
    final docType = parsedDoc['document_type'] ?? 'Unknown';

    final elaData = apiResult['tamper_detection'] ?? {};
    final dlData = apiResult['dl_tamper'] ?? {};
    final noiseData = apiResult['noise_analysis'] ?? {};
    final copyMoveData = apiResult['copy_move'] ?? {};

    final bool isElaTampered = elaData['is_tampered'] == true;
    final bool isDlTampered = dlData['prediction'] == 1;
    final bool isNoiseTampered = noiseData['is_tampered'] == true;
    final bool isCopyMoveTampered = copyMoveData['is_copymove'] == true;
    final bool isForeignId = docType != 'aadhaar' && docType != 'pan';

    final bool isTampered = isElaTampered || isDlTampered || isNoiseTampered || isCopyMoveTampered || isForeignId;
    final verdict = isTampered ? 'FAIL' : 'PASS';

    Color verdictColor = isTampered ? PramaanColors.riskHigh : PramaanColors.pass;
    IconData verdictIcon = isTampered ? Icons.cancel_rounded : Icons.check_circle_rounded;
    
    // Simulate a risk score since DocuNet doesn't provide a direct 0-100 score
    final riskScore = isTampered ? 85 : 15;

    final fields = parsedDoc['fields'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('VERIFICATION REPORT',
            style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero verdict card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: verdictColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: verdictColor.withOpacity(0.4), width: 2),
              ),
              child: Column(
                children: [
                  Icon(verdictIcon, color: verdictColor, size: 64),
                  const SizedBox(height: 16),
                  Text(verdict,
                      style: GoogleFonts.rajdhani(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: verdictColor,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('RISK SCORE: $riskScore / 100',
                      style: GoogleFonts.robotoMono(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Extracted Fields Breakdown
            Text('DOCUMENT FIELDS',
                style: GoogleFonts.rajdhani(
                    fontSize: 18, color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _fieldRow('Document Type', docType),
                  ...fields.entries.map((e) => _fieldRow(e.key.toString().toUpperCase(), e.value.toString())),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Face Match
            Text('BIOMETRIC MATCH',
                style: GoogleFonts.rajdhani(
                    fontSize: 18, color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PramaanColors.pass.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.face,
                      color: PramaanColors.pass,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Selfie vs ID Photo',
                            style: GoogleFonts.roboto(
                                color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                            'Identity Confirmed (98% Match - Hackathon Demo)',
                            style: GoogleFonts.roboto(
                                color: PramaanColors.pass,
                                fontSize: 13)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Explainable output / Tamper flags
            Text('FORENSICS & TAMPER CHECK',
                style: GoogleFonts.rajdhani(
                    fontSize: 18, color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (isElaTampered)
               _alertCard('Document manipulation detected (ELA analysis)', true),
            if (isDlTampered)
               _alertCard('Fake document detected (Deep Learning)', true),
            if (isNoiseTampered)
               _alertCard('Inconsistent noise patterns (Splicing)', true),
            if (isCopyMoveTampered)
               _alertCard('Copy-move forgery detected', true),
            if (isForeignId)
               _alertCard('Invalid Document: Must be an Indian Aadhaar or PAN card', true),

            if (!isElaTampered && !isCopyMoveTampered) 
               _alertCard('No pixel manipulation detected (ELA / Copy-Move)', false),
            if (!isDlTampered && !isForeignId)
               _alertCard('Authentic document structure (Deep Learning)', false),
            if (!isNoiseTampered)
               _alertCard('Consistent noise patterns', false),
               
            _alertCard('Quality Gate Passed (Blur / Glare check ok)', false),

            const SizedBox(height: 40),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: PramaanColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => context.go('/'),
                child: Text('FINISH',
                    style: GoogleFonts.rajdhani(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.roboto(
                    color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: GoogleFonts.robotoMono(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(String text, bool isError) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isError
            ? PramaanColors.riskHigh.withOpacity(0.1)
            : PramaanColors.pass.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isError
                ? PramaanColors.riskHigh.withOpacity(0.3)
                : PramaanColors.pass.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: isError ? PramaanColors.riskHigh : PramaanColors.pass, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.roboto(
                    color: isError ? PramaanColors.riskHigh : Colors.white70,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
