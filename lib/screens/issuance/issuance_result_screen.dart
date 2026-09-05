import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/issued_document.dart';
import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';

class IssuanceResultScreen extends ConsumerStatefulWidget {
  final String documentId;
  const IssuanceResultScreen({super.key, required this.documentId});

  @override
  ConsumerState<IssuanceResultScreen> createState() =>
      _IssuanceResultScreenState();
}

class _IssuanceResultScreenState extends ConsumerState<IssuanceResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  IssuedDocument? _doc;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      final doc = storage.getDocument(widget.documentId);
      setState(() => _doc = doc);
      _ctrl.forward();
      // Reset the form for next use
      ref.read(issuanceFormProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _copyId() {
    if (_doc == null) return;
    Clipboard.setData(ClipboardData(text: _doc!.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document ID copied to clipboard'),
        backgroundColor: PramaanColors.steelBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_doc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: PramaanColors.navyDark,
      appBar: AppBar(
        title: const Text('DOCUMENT ISSUED'),
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
        padding: const EdgeInsets.all(20),
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PramaanColors.pass.withOpacity(0.2),
                  PramaanColors.pass.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PramaanColors.pass.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: PramaanColors.pass.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: PramaanColors.pass.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.verified, color: PramaanColors.pass, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Successfully Issued',
                        style: GoogleFonts.rajdhani(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: PramaanColors.pass,
                        ),
                      ),
                      Text(
                        'Ed25519 signature applied · QR code generated',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: PramaanColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: PramaanColors.steelBlue.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _doc!.id,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: PramaanColors.navyPrimary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: PramaanColors.navyPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Record ID
          GestureDetector(
            onTap: _copyId,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Record ID: ${_doc!.displayId}',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: PramaanColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.copy, size: 14, color: PramaanColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PramaanColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PramaanColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        color: PramaanColors.steelBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SIGNED RECORD',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: PramaanColors.steelBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._doc!.displayFields.entries.map(
                  (e) => _FieldRow(label: e.key, value: e.value),
                ),
                const SizedBox(height: 16),
                // Photo thumbnail
                if (File(_doc!.photoPath).existsSync())
                  Row(
                    children: [
                      Text(
                        'Captured Photo',
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: PramaanColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_doc!.photoPath),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Signature preview
                Text(
                  'Ed25519 Signature:',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: PramaanColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_doc!.signature.substring(0, 24)}…',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: PramaanColors.steelBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pushNamed('issuance-form'),
                  icon: const Icon(Icons.add),
                  label: const Text('ISSUE ANOTHER'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.goNamed('splash'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('HOME'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: PramaanColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: PramaanColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
