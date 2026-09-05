import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/issued_document.dart';
import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';

class CheckpointScanScreen extends ConsumerStatefulWidget {
  const CheckpointScanScreen({super.key});

  @override
  ConsumerState<CheckpointScanScreen> createState() =>
      _CheckpointScanScreenState();
}

class _CheckpointScanScreenState extends ConsumerState<CheckpointScanScreen> {
  MobileScannerController? _scannerCtrl;
  bool _scanned = false;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _scannerCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerCtrl?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _scanned = true;
    _scannerCtrl?.stop();

    final storage = ref.read(storageServiceProvider);
    final doc = storage.getDocument(code);

    if (doc == null) {
      setState(() => _scanned = false);
      _scannerCtrl?.start();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document not found in database. Try manual selection.'),
          backgroundColor: PramaanColors.riskHigh,
        ),
      );
      return;
    }

    _navigateToFace(doc.id);
  }

  void _navigateToFace(String docId) {
    context.pushNamed(
      'checkpoint-face',
      queryParameters: {'docId': docId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'CHECKPOINT — SCAN DOCUMENT',
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showList = !_showList),
            child: Text(
              _showList ? 'SCAN' : 'SELECT',
              style: GoogleFonts.rajdhani(
                color: PramaanColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _showList
          ? _DocumentListPicker(
              onSelect: (docId) {
                setState(() => _showList = false);
                _navigateToFace(docId);
              },
            )
          : _ScannerView(
              controller: _scannerCtrl!,
              onDetect: _onDetect,
            ),
    );
  }
}

class _ScannerView extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  const _ScannerView({required this.controller, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
        ),

        // Dark overlay with scan frame
        CustomPaint(
          painter: _ScanFramePainter(),
          child: Container(),
        ),

        // Status text
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner,
                  color: Colors.white54, size: 24),
              const SizedBox(height: 8),
              Text(
                'Align QR code with the frame',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Or tap SELECT to choose from issued documents',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frameSize = size.width * 0.65;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;
    final rect = Rect.fromLTWH(left, top, frameSize, frameSize);

    // Dark overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = PramaanColors.steelBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const bracketLen = 24.0;

    void drawCorner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx, y), bracketPaint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy), bracketPaint);
    }

    drawCorner(left, top, bracketLen, bracketLen);
    drawCorner(left + frameSize, top, -bracketLen, bracketLen);
    drawCorner(left, top + frameSize, bracketLen, -bracketLen);
    drawCorner(left + frameSize, top + frameSize, -bracketLen, -bracketLen);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _DocumentListPicker extends ConsumerWidget {
  final void Function(String docId) onSelect;

  const _DocumentListPicker({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final docs = storage.getAllDocuments();

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined,
                color: PramaanColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No issued documents found',
              style: GoogleFonts.roboto(color: PramaanColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'Issue a document first from the Issuance mode',
              style: GoogleFonts.roboto(
                color: PramaanColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) => _DocListTile(doc: docs[i], onTap: () => onSelect(docs[i].id)),
    );
  }
}

class _DocListTile extends StatelessWidget {
  final IssuedDocument doc;
  final VoidCallback onTap;

  const _DocListTile({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isExpired = DateTime.tryParse(doc.expiry)?.isBefore(DateTime.now()) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PramaanColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpired
              ? PramaanColors.riskHigh.withOpacity(0.4)
              : PramaanColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PramaanColors.steelBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _docIcon(doc.docType),
            color: PramaanColors.steelBlue,
            size: 26,
          ),
        ),
        title: Text(
          doc.name,
          style: GoogleFonts.rajdhani(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: PramaanColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${doc.docType} · ${doc.idNumber} · Expires: ${doc.expiry}',
          style: GoogleFonts.roboto(
            fontSize: 12,
            color: isExpired ? PramaanColors.riskHigh : PramaanColors.textMuted,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: PramaanColors.steelBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            doc.displayId,
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PramaanColors.steelBlue,
              letterSpacing: 1,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _docIcon(String type) {
    switch (type) {
      case 'Passport':
        return Icons.book_outlined;
      case 'Visa':
        return Icons.approval_outlined;
      case 'National ID':
        return Icons.badge_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
