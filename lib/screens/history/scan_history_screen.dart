import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/scan_record.dart';
import '../../providers.dart';
import '../../services/storage_service.dart';
import '../../widgets/pramaan_theme.dart';

class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final scans = storage.getAllScans();
    final duplicates = storage.findDuplicateFaces(threshold: 0.85);
    final duplicateScanIds = <String>{};
    for (final d in duplicates) {
      duplicateScanIds.add(d.scanA.id);
      duplicateScanIds.add(d.scanB.id);
    }

    return Scaffold(
      backgroundColor: PramaanColors.surfaceDark,
      appBar: AppBar(
        title: const Text('SCAN HISTORY'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: scans.isEmpty
          ? _EmptyHistory()
          : Column(
              children: [
                // Duplicate face alerts
                if (duplicates.isNotEmpty)
                  _DuplicateFaceAlert(
                    count: duplicates.length,
                    alerts: duplicates,
                  ),

                // Stats row
                _StatsRow(scans: scans),

                // List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: scans.length,
                    itemBuilder: (_, i) => _ScanTile(
                      scan: scans[i],
                      hasDuplicateFlag: duplicateScanIds.contains(scans[i].id),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off,
              color: PramaanColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text(
            'No scans yet',
            style: GoogleFonts.rajdhani(
              fontSize: 20,
              color: PramaanColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a checkpoint verification to see history',
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: PramaanColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateFaceAlert extends StatelessWidget {
  final int count;
  final List<DuplicateFaceAlert> alerts;

  const _DuplicateFaceAlert({required this.count, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PramaanColors.riskCritical.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PramaanColors.riskCritical.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: PramaanColors.riskCritical, size: 22),
              const SizedBox(width: 10),
              Text(
                'MULTIPLE IDENTITY ALERT',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: PramaanColors.riskCritical,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count face(s) detected across multiple document IDs. Possible identity fraud.',
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: PramaanColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...alerts.take(3).map((a) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${a.scanA.documentName} (${a.scanA.documentId.substring(0, 6).toUpperCase()}) ↔ '
                  '${a.scanB.documentName} (${a.scanB.documentId.substring(0, 6).toUpperCase()}) '
                  '— ${(a.similarity * 100).toStringAsFixed(0)}% face similarity',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: PramaanColors.riskCritical,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<ScanRecord> scans;

  const _StatsRow({required this.scans});

  @override
  Widget build(BuildContext context) {
    final approved = scans.where((s) => s.isApproved).length;
    final flagged = scans.where((s) => s.isFlagged).length;
    final highRisk = scans
        .where((s) => s.riskLevel == 'HIGH' || s.riskLevel == 'CRITICAL')
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: PramaanColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PramaanColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCell(value: scans.length.toString(), label: 'TOTAL'),
          _Divider(),
          _StatCell(
            value: approved.toString(),
            label: 'APPROVED',
            color: PramaanColors.riskLow,
          ),
          _Divider(),
          _StatCell(
            value: flagged.toString(),
            label: 'FLAGGED',
            color: PramaanColors.riskHigh,
          ),
          _Divider(),
          _StatCell(
            value: highRisk.toString(),
            label: 'HIGH RISK',
            color: PramaanColors.riskCritical,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatCell({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.rajdhani(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color ?? PramaanColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 10,
            color: PramaanColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: PramaanColors.divider,
    );
  }
}

class _ScanTile extends StatelessWidget {
  final ScanRecord scan;
  final bool hasDuplicateFlag;

  const _ScanTile({required this.scan, required this.hasDuplicateFlag});

  Color _riskColor(String level) {
    switch (level) {
      case 'LOW':
        return PramaanColors.riskLow;
      case 'MEDIUM':
        return PramaanColors.riskMedium;
      case 'HIGH':
        return PramaanColors.riskHigh;
      case 'CRITICAL':
        return PramaanColors.riskCritical;
      default:
        return PramaanColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(scan.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: PramaanColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDuplicateFlag
              ? PramaanColors.riskCritical.withOpacity(0.5)
              : PramaanColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              scan.riskLevel.substring(0, 1),
              style: GoogleFonts.rajdhani(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                scan.documentName,
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PramaanColors.textPrimary,
                ),
              ),
            ),
            if (hasDuplicateFlag)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PramaanColors.riskCritical.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: PramaanColors.riskCritical.withOpacity(0.4)),
                ),
                child: Text(
                  'DUPLICATE FACE',
                  style: GoogleFonts.roboto(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: PramaanColors.riskCritical,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${scan.documentType} · ${scan.scannedAt.toLocal().toString().substring(0, 16)}',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: PramaanColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Risk: ${scan.riskScore.toStringAsFixed(0)} · ',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: color,
                  ),
                ),
                Text(
                  'Face: ${(scan.faceMatchScore * 100).toStringAsFixed(0)}% · ',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: PramaanColors.textMuted,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: scan.isApproved
                        ? PramaanColors.riskLow.withOpacity(0.15)
                        : PramaanColors.riskHigh.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    scan.action,
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scan.isApproved
                          ? PramaanColors.riskLow
                          : PramaanColors.riskHigh,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
