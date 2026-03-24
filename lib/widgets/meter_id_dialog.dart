import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class MeterIdDialog extends StatefulWidget {
  const MeterIdDialog({super.key});

  @override
  State<MeterIdDialog> createState() => _MeterIdDialogState();
}

class _MeterIdDialogState extends State<MeterIdDialog> {
  final _meterIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _meterIdController.dispose();
    super.dispose();
  }

  Future<void> _submitMeterId() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simulate fetching meter data
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.of(context).pop(_meterIdController.text.trim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, AppTheme.surfaceColor],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.electric_meter,
                  size: 40,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Enter Smart Meter ID',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter your smart meter ID to view your electricity metrics',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Meter ID Input
              TextFormField(
                controller: _meterIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Smart Meter ID',
                  hintText: 'e.g., SM-12345678',
                  prefixIcon: const Icon(
                    Icons.qr_code,
                    color: AppTheme.primaryGreen,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.lightGreen.withAlpha(128),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your meter ID';
                  }
                  if (value.trim().length < 3) {
                    return 'Meter ID must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitMeterId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Connect to Meter',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              // Demo hint
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppTheme.darkGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Demo: Try "SM-DEMO-001"',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
