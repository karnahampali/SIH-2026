import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/issued_document.dart';
import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';

enum _TamperAction { swapPhoto, editDob, cloneDoc }

class TamperDemoScreen extends ConsumerStatefulWidget {
  const TamperDemoScreen({super.key});

  @override
  ConsumerState<TamperDemoScreen> createState() => _TamperDemoScreenState();
}

class _TamperDemoScreenState extends ConsumerState<TamperDemoScreen>
    with SingleTickerProviderStateMixin {
  IssuedDocument? _selectedDoc;
  _TamperAction? _selectedTamper;
  String? _swapPhotoPath;
  late AnimationController _warnCtrl;
  late Animation<double> _warnPulse;

  @override
  void initState() {
    super.initState();
    _warnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _warnPulse = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _warnCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _warnCtrl.dispose();
    super.dispose();
  }

  void _pickSwapPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) {
      setState(() {
        _swapPhotoPath = picked.path;
        _selectedTamper = _TamperAction.swapPhoto;
      });
    }
  }

  void _runVerification() {
    if (_selectedDoc == null || _selectedTamper == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a document and a tamper type first'),
          backgroundColor: PramaanColors.riskHigh,
        ),
      );
      return;
    }

    String tamperParam;
    switch (_selectedTamper!) {
      case _TamperAction.swapPhoto:
        tamperParam = 'swapPhoto';
        break;
      case _TamperAction.editDob:
        tamperParam = 'editDob';
        break;
      case _TamperAction.cloneDoc:
        tamperParam = 'clone';
        break;
    }

    // We need a face photo — use the stored photo as the "live" face for demo
    final facePhoto = _swapPhotoPath ?? _selectedDoc!.photoPath;

    context.pushNamed(
      'checkpoint-progress',
      queryParameters: {
        'docId': _selectedDoc!.id,
        'facePhoto': facePhoto,
        'tamper': tamperParam,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageServiceProvider);
    final docs = storage.getAllDocuments();

    return Scaffold(
      backgroundColor: PramaanColors.surfaceDark,
      appBar: AppBar(
        title: const Text('TAMPER DEMO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Warning banner
          AnimatedBuilder(
            animation: _warnPulse,
            builder: (_, child) => Transform.scale(
              scale: _warnPulse.value,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PramaanColors.accent.withOpacity(0.2),
                    PramaanColors.riskHigh.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PramaanColors.accent.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: PramaanColors.accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEMO MODE — SIMULATED TAMPER',
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: PramaanColors.accent,
                          ),
                        ),
                        Text(
                          'This does NOT modify stored records. Tamper is applied in-memory only.',
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
          ),
          const SizedBox(height: 24),

          // Step 1: Select document
          _sectionHeader('STEP 1 — SELECT DOCUMENT'),
          const SizedBox(height: 12),

          if (docs.isEmpty)
            Center(
              child: Text(
                'No issued documents. Issue a document first.',
                style: GoogleFonts.roboto(color: PramaanColors.textMuted),
              ),
            )
          else
            ...docs.map((doc) => _DocSelectTile(
                  doc: doc,
                  selected: _selectedDoc?.id == doc.id,
                  onTap: () => setState(() => _selectedDoc = doc),
                )),

          const SizedBox(height: 24),

          // Step 2: Select tamper
          _sectionHeader('STEP 2 — SELECT TAMPER TYPE'),
          const SizedBox(height: 12),

          _TamperTile(
            icon: Icons.face,
            title: 'Swap Photo',
            subtitle: 'Replace the document photo with a different face → triggers Photo Fingerprint & Face Match failures',
            color: PramaanColors.riskCritical,
            selected: _selectedTamper == _TamperAction.swapPhoto,
            onTap: _pickSwapPhoto,
          ),
          const SizedBox(height: 10),
          _TamperTile(
            icon: Icons.edit_calendar,
            title: 'Edit Date of Birth',
            subtitle: 'Alter DOB by 2 years → invalidates Ed25519 signature → triggers Document Signature failure',
            color: PramaanColors.riskHigh,
            selected: _selectedTamper == _TamperAction.editDob,
            onTap: () => setState(() => _selectedTamper = _TamperAction.editDob),
          ),
          const SizedBox(height: 10),
          _TamperTile(
            icon: Icons.content_copy,
            title: 'Clone Document',
            subtitle: 'Present same doc ID with a different name → triggers all signature & identity checks',
            color: PramaanColors.riskMedium,
            selected: _selectedTamper == _TamperAction.cloneDoc,
            onTap: () => setState(() => _selectedTamper = _TamperAction.cloneDoc),
          ),

          // Swap photo indicator
          if (_selectedTamper == _TamperAction.swapPhoto && _swapPhotoPath != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_swapPhotoPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Swap photo selected',
                  style: GoogleFonts.roboto(
                    color: PramaanColors.riskCritical,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Expected failure hint
          if (_selectedTamper != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PramaanColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PramaanColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPECTED FAILURE',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: PramaanColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _expectedFailure(_selectedTamper!),
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: PramaanColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Run button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: PramaanColors.riskHigh,
              ),
              onPressed: (_selectedDoc != null && _selectedTamper != null)
                  ? _runVerification
                  : null,
              icon: const Icon(Icons.play_arrow, size: 24),
              label: const Text('RUN VERIFICATION WITH TAMPER'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _expectedFailure(_TamperAction action) {
    switch (action) {
      case _TamperAction.swapPhoto:
        return '📸 Photo Fingerprint — Hash mismatch with signed record\n'
            '👤 Face Match — New face does not match stored document photo\n'
            '🔐 Document Signature — Signature remains valid (data fields unchanged)';
      case _TamperAction.editDob:
        return '🔐 Document Signature — Signature FAILS because canonical string changes\n'
            '📋 Field data shows DOB mismatch with signed record\n'
            '👤 Face Match — Not affected (same person)';
      case _TamperAction.cloneDoc:
        return '🔐 Document Signature — Fails because name field changed\n'
            '🗃️ Identity History — Different name linked to same document ID\n'
            '📸 Photo Fingerprint — May pass (same doc reference)';
    }
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: PramaanColors.accent,
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
            color: PramaanColors.accent,
          ),
        ),
      ],
    );
  }
}

class _DocSelectTile extends StatelessWidget {
  final IssuedDocument doc;
  final bool selected;
  final VoidCallback onTap;

  const _DocSelectTile({
    required this.doc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? PramaanColors.primary.withOpacity(0.15)
              : PramaanColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? PramaanColors.primary : PramaanColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (File(doc.photoPath).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(doc.photoPath),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PramaanColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: PramaanColors.textMuted),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PramaanColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${doc.docType} · ${doc.idNumber}',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: PramaanColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: PramaanColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _TamperTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TamperTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : PramaanColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : PramaanColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : PramaanColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: PramaanColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
