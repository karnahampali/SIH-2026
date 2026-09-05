import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/pramaan_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PramaanColors.navyDark,
      appBar: AppBar(
        title: const Text('ABOUT PRAMAAN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Logo & title
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [PramaanColors.steelBlue, PramaanColors.navyPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PramaanColors.steelBlue.withOpacity(0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'PRAMAAN',
                  style: GoogleFonts.rajdhani(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6.0,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'प्रमाण — Authentication',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: PramaanColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: PramaanColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PramaanColors.divider),
                  ),
                  child: Text(
                    'Smart India Hackathon 2024',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: PramaanColors.steelBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Description
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: PramaanColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PramaanColors.divider),
            ),
            child: Text(
              'PRAMAAN is an AI-powered multi-layer document and identity authentication system designed for border checkpoints. It combines cryptographic signing, perceptual image fingerprinting, and biometric face matching to provide tamper-evident, explainable verification results in real time.',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: PramaanColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader('CORE TECHNIQUES'),
          const SizedBox(height: 12),

          _TechCard(
            icon: Icons.key,
            title: 'Ed25519 Digital Signatures',
            color: PramaanColors.steelBlue,
            description:
                'Each issued document is signed with an Ed25519 elliptic-curve key pair. '
                'The signature covers all document fields plus the photo fingerprint — '
                'any single bit change causes verification to fail immediately.',
            details: [
              'Elliptic-curve Diffie-Hellman over Curve25519',
              '256-bit security level',
              'Signature: 64 bytes (512 bits)',
              'Implemented via the `cryptography` Dart package',
            ],
          ),
          const SizedBox(height: 12),

          _TechCard(
            icon: Icons.fingerprint,
            title: 'Perceptual Image Hashing (dHash)',
            color: PramaanColors.riskMedium,
            description:
                'A difference-hash (dHash) of the document photo is included in the signed '
                'payload. Any significant image substitution changes the hash, causing the '
                'signature to fail even before the face match step.',
            details: [
              '8×9 grayscale resize → 64-bit difference hash',
              'Hamming distance for similarity scoring',
              'Resistant to minor compression artifacts',
              'Implemented via the `image` Dart package',
            ],
          ),
          const SizedBox(height: 12),

          _TechCard(
            icon: Icons.face,
            title: 'Biometric Face Matching',
            color: const Color(0xFF8E44AD),
            description:
                'At checkpoint, a live photo is captured and compared to the signed document '
                'photo using pixel-region similarity on grayscale normalized crops. '
                'ML Kit face detection provides landmark points for accuracy.',
            details: [
              'google_mlkit_face_detection for landmark detection',
              '32×32 grayscale normalized face crop comparison',
              'Cosine similarity + mean-squared-error fusion',
              'Threshold: 70% similarity for PASS',
            ],
          ),
          const SizedBox(height: 12),

          _TechCard(
            icon: Icons.remove_red_eye_outlined,
            title: 'Liveness Heuristic',
            color: PramaanColors.pass,
            description:
                'A basic liveness check prompts the subject to blink and turn their head. '
                'Frame-difference analysis and ML Kit eye-open probabilities are combined '
                'to detect whether a live subject is present vs. a static photo/screen.',
            details: [
              'Head Euler angle movement detection (>5° = live)',
              'Eye blink detection via leftEyeOpenProbability',
              'Multi-frame analysis over 6-second window',
              'Weight: 10% of risk score',
            ],
          ),
          const SizedBox(height: 12),

          _TechCard(
            icon: Icons.storage,
            title: 'Identity History Cross-Check',
            color: PramaanColors.accent,
            description:
                'All checkpoint scans are stored locally with face embeddings. '
                'Cosine similarity between embeddings across different document IDs '
                'flags potential multiple-identity fraud.',
            details: [
              '64-element face luminance embedding',
              'Cosine similarity threshold: 0.85',
              'Prior scan flagging: high-risk history weighs −15 pts',
              'Implemented in Hive local storage',
            ],
          ),
          const SizedBox(height: 12),

          _TechCard(
            icon: Icons.calculate,
            title: 'Weighted Risk Formula',
            color: PramaanColors.riskCritical,
            description:
                'A transparent, explainable risk score from 0–100 is computed as a '
                'weighted sum across all five modules. Each module can be independently '
                'explained to the officer.',
            details: [
              'risk = 25×(1−doc) + 25×(1−photo) + 25×(1−face)',
              '       + 15×(1−db) + 10×(1−liveness)',
              'LOW: 0–19 · MEDIUM: 20–44 · HIGH: 45–69 · CRITICAL: 70+',
              'Per-module plain-language reasons shown in UI',
            ],
          ),

          const SizedBox(height: 24),
          _sectionHeader('TECH STACK'),
          const SizedBox(height: 12),

          _StackGrid(),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Built with Flutter · Dart 3.12 · Material 3',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: PramaanColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: PramaanColors.steelBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.rajdhani(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: PramaanColors.steelBlue,
          ),
        ),
      ],
    );
  }
}

class _TechCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final String description;
  final List<String> details;

  const _TechCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.description,
    required this.details,
  });

  @override
  State<_TechCard> createState() => _TechCardState();
}

class _TechCardState extends State<_TechCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PramaanColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? widget.color.withOpacity(0.4)
              : PramaanColors.divider,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.color.withOpacity(0.3)),
            ),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.rajdhani(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PramaanColors.textPrimary,
            ),
          ),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: widget.color.withOpacity(0.2)),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: PramaanColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.details.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '→ ',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: widget.color,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              d,
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: PramaanColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackGrid extends StatelessWidget {
  final _items = const [
    ('Flutter 3.44', Icons.flutter_dash),
    ('Dart 3.12', Icons.code),
    ('Riverpod', Icons.hub_outlined),
    ('Hive DB', Icons.storage),
    ('ML Kit', Icons.face),
    ('Ed25519', Icons.key),
    ('GoRouter', Icons.route),
    ('QR Flutter', Icons.qr_code),
  ];

  const _StackGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: _items.map((item) {
        return Container(
          decoration: BoxDecoration(
            color: PramaanColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PramaanColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.$2, color: PramaanColors.steelBlue, size: 22),
              const SizedBox(height: 6),
              Text(
                item.$1,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 10,
                  color: PramaanColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
