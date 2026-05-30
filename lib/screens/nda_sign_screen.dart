import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fundmate_app/services/nda_service.dart';
import 'startup_detail_screen.dart';
import 'package:fundmate_app/theme/app_colors.dart';
import 'package:fundmate_app/widgets/fundmate_app_bar.dart';

/// Shown when investor taps "Show Interest". After agreeing, opens description
/// and interest is sent to the entrepreneur automatically.
class NdaSignScreen extends StatefulWidget {
  final String startupId;
  final String startupName;

  const NdaSignScreen({
    super.key,
    required this.startupId,
    required this.startupName,
  });

  @override
  State<NdaSignScreen> createState() => _NdaSignScreenState();
}

class _NdaSignScreenState extends State<NdaSignScreen> {
  bool _agreed = false;
  bool _isLoading = false;

  String get userId => FirebaseAuth.instance.currentUser!.uid;
  String get userEmail => FirebaseAuth.instance.currentUser?.email ?? '';
  String get userName =>
      FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Investor';

  Future<void> _agreeAndViewDescription() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the box to agree to the NDA'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final alreadySigned = await NdaService.hasSigned(userId);
      if (!alreadySigned) {
        await NdaService.signNda(
          investorId: userId,
          investorName: userName,
          investorEmail: userEmail,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StartupDetailScreen(
            startupId: widget.startupId,
            sendInterestOnLoad: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const FundMateAppBar(
        title: 'Non-Disclosure Agreement',
        subtitle: 'Step 1 of 2 — Review & agree',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fm.unreadTint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Showing interest in: ${widget.startupName}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'After you agree, you will see the full startup description and your interest will be sent to the entrepreneur.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'FundMate Investor NDA',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: fm.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: fm.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: fm.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'By signing this agreement, you agree to keep all startup information '
                      'confidential, including business plans, financial details, and proprietary '
                      'data shared on FundMate. You will not disclose, copy, or use this information '
                      'for any purpose other than evaluating a potential investment.\n\n'
                      'This obligation continues after you leave the platform. Unauthorized sharing '
                      'may result in removal from FundMate and possible legal action.\n\n'
                      'You confirm that you are accessing startup data solely for legitimate '
                      'investment evaluation purposes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            fontSize: 14,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: fm.card,
                    borderRadius: BorderRadius.circular(12),
                    child: CheckboxListTile(
                      value: _agreed,
                      onChanged: _isLoading
                          ? null
                          : (v) => setState(() => _agreed = v ?? false),
                      activeColor: scheme.primary,
                      title: Text(
                        'I have read and agree to the Non-Disclosure Agreement',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                            ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _agreeAndViewDescription,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Text('I Agree — View Description'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
