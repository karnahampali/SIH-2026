import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';

class IssuanceFormScreen extends ConsumerStatefulWidget {
  const IssuanceFormScreen({super.key});

  @override
  ConsumerState<IssuanceFormScreen> createState() => _IssuanceFormScreenState();
}

class _IssuanceFormScreenState extends ConsumerState<IssuanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();

  String _dob = '';
  String _expiry = '';
  String _docType = 'Passport';

  final _docTypes = ['Passport', 'Visa', 'National ID', 'Border Pass'];

  @override
  void initState() {
    super.initState();
    final existing = ref.read(issuanceFormProvider);
    _nameCtrl.text = existing.name;
    _idCtrl.text = existing.idNumber;
    _nationalityCtrl.text = existing.nationality;
    _dob = existing.dob;
    _expiry = existing.expiry;
    _docType = existing.docType.isNotEmpty ? existing.docType : 'Passport';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _nationalityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDob) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? DateTime(1990, 1, 1) : now.add(const Duration(days: 365 * 5)),
      firstDate: isDob ? DateTime(1920) : now,
      lastDate: isDob ? now : now.add(const Duration(days: 365 * 20)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: PramaanColors.steelBlue,
              surface: PramaanColors.surfaceCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final formatted = DateFormat('yyyy-MM-dd').format(picked);
        if (isDob) _dob = formatted;
        else _expiry = formatted;
      });
    }
  }

  void _proceed() {
    if (!_formKey.currentState!.validate()) return;
    if (_dob.isEmpty) {
      _showError('Please select Date of Birth.');
      return;
    }
    if (_expiry.isEmpty) {
      _showError('Please select Expiry Date.');
      return;
    }

    ref.read(issuanceFormProvider.notifier).update(
      ref.read(issuanceFormProvider).copyWith(
        name: _nameCtrl.text.trim(),
        idNumber: _idCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim(),
        dob: _dob,
        expiry: _expiry,
        docType: _docType,
      ),
    );

    context.pushNamed('issuance-photo');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: PramaanColors.fail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PramaanColors.navyDark,
      appBar: AppBar(
        title: const Text('ISSUANCE — DOCUMENT DETAILS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionHeader('Document Information'),
            const SizedBox(height: 12),

            // Document type
            DropdownButtonFormField<String>(
              value: _docType,
              decoration: const InputDecoration(
                labelText: 'Document Type',
                prefixIcon: Icon(Icons.description_outlined, color: PramaanColors.steelBlue),
              ),
              dropdownColor: PramaanColors.surfaceCard,
              style: GoogleFonts.roboto(color: PramaanColors.textPrimary, fontSize: 15),
              items: _docTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _docType = v!),
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _idCtrl,
              label: 'Document / ID Number',
              icon: Icons.badge_outlined,
              hint: 'e.g. P1234567',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _sectionHeader('Personal Information'),
            const SizedBox(height: 12),

            _buildField(
              controller: _nameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline,
              hint: 'As on document',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // DOB picker
            _DatePickerField(
              label: 'Date of Birth',
              value: _dob,
              icon: Icons.cake_outlined,
              onTap: () => _pickDate(true),
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _nationalityCtrl,
              label: 'Nationality',
              icon: Icons.flag_outlined,
              hint: 'e.g. Indian',
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _sectionHeader('Validity'),
            const SizedBox(height: 12),

            // Expiry picker
            _DatePickerField(
              label: 'Expiry Date',
              value: _expiry,
              icon: Icons.event_outlined,
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 36),

            // Proceed button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _proceed,
                icon: const Icon(Icons.camera_alt_outlined, size: 22),
                label: const Text('NEXT: CAPTURE PHOTO'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, 
          decoration: BoxDecoration(color: PramaanColors.steelBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.roboto(color: PramaanColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: PramaanColors.steelBlue, size: 22),
      ),
      validator: validator,
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PramaanColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value.isNotEmpty
                ? PramaanColors.steelBlue
                : PramaanColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: value.isNotEmpty
                    ? PramaanColors.steelBlue
                    : PramaanColors.textMuted,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: value.isNotEmpty
                          ? PramaanColors.steelBlue
                          : PramaanColors.textMuted,
                    ),
                  ),
                  if (value.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        color: PramaanColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.calendar_today,
                color: PramaanColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
