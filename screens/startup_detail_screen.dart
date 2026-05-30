import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'nda_sign_screen.dart';
import 'services/chat_service.dart';
import 'services/nda_service.dart';
import 'theme/app_colors.dart';
import 'widgets/fundmate_app_bar.dart';

class StartupDetailScreen extends StatefulWidget {
  final String startupId;
  /// When true (from Show Interest flow), sends interest after NDA + viewing description.
  final bool sendInterestOnLoad;

  const StartupDetailScreen({
    super.key,
    required this.startupId,
    this.sendInterestOnLoad = false,
  });

  @override
  State<StartupDetailScreen> createState() => _StartupDetailScreenState();
}

class _StartupDetailScreenState extends State<StartupDetailScreen> {
  bool _isSendingInterest = false;
  bool _interestSent = false;
  bool _interestAttempted = false;

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _sendInterestToEntrepreneur() async {
    if (_interestSent || _isSendingInterest) return;

    setState(() => _isSendingInterest = true);
    try {
      await FirebaseFirestore.instance
          .collection('startups')
          .doc(widget.startupId)
          .update({
        'interestedInvestors': FieldValue.arrayUnion([userId]),
      });

      final investorName =
          FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Investor';
      await ChatService.ensureInvestmentChatFromStartup(
        widget.startupId,
        userId,
        investorName,
      );

      if (mounted) {
        setState(() => _interestSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your interest was sent! You can message the entrepreneur in Chats.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send interest: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSendingInterest = false);
  }

  void _maybeSendInterestFromFlow(bool alreadyInterested) {
    if (!widget.sendInterestOnLoad || _interestAttempted) return;
    _interestAttempted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (alreadyInterested) {
        setState(() => _interestSent = true);
        return;
      }
      _sendInterestToEntrepreneur();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fm = context.fundMate;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: FundMateAppBar(
        title: 'Startup Details',
        subtitle: widget.sendInterestOnLoad
            ? 'Step 2 of 2 — Description & interest'
            : 'Confidential — NDA protected',
        showBackButton: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('startups')
            .doc(widget.startupId)
            .snapshots(),
        builder: (context, startupSnapshot) {
          if (startupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!startupSnapshot.hasData || !startupSnapshot.data!.exists) {
            return const Center(child: Text('Startup not found'));
          }

          final startup = startupSnapshot.data!.data()!;
          final name = startup['name']?.toString() ?? 'Startup';
          final sector = startup['sector']?.toString() ?? '';
          final funding = startup['fundingNeeded']?.toString() ?? '0';
          final description =
              startup['description']?.toString().trim() ??
                  'No description provided.';
          final alreadyInterested =
              (startup['interestedInvestors'] as List?)?.contains(userId) ??
                  false;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: NdaService.signatureStream(userId),
            builder: (context, ndaSnapshot) {
              if (ndaSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final hasSigned = ndaSnapshot.data?.exists == true &&
                  ndaSnapshot.data?.data()?['signed'] == true;

              if (!hasSigned) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 72, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        'NDA required',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NdaSignScreen(
                                startupId: widget.startupId,
                                startupName: name,
                              ),
                            ),
                          );
                        },
                        child: const Text('Go to NDA'),
                      ),
                    ],
                  ),
                );
              }

              _maybeSendInterestFromFlow(alreadyInterested);

              final showInterestConfirmed =
                  _interestSent || alreadyInterested;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showInterestConfirmed) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.sendInterestOnLoad
                                    ? 'Interest sent to the entrepreneur!'
                                    : 'You have already expressed interest',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isSendingInterest) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Sending your interest...'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [fm.gradientStart, fm.gradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (sector.isNotEmpty)
                            Text(
                              sector,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            '\$$funding funding needed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Full Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: fm.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: fm.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: fm.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                              fontSize: 15,
                            ),
                      ),
                    ),
                    if (!widget.sendInterestOnLoad && !showInterestConfirmed) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSendingInterest ? null : _sendInterestToEntrepreneur,
                          icon: const Icon(Icons.favorite),
                          label: const Text('Express Interest'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (showInterestConfirmed) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final investorName = FirebaseAuth
                                      .instance.currentUser?.email
                                      ?.split('@')
                                      .first ??
                                  'Investor';
                              final chatId =
                                  await ChatService.ensureInvestmentChatFromStartup(
                                widget.startupId,
                                userId,
                                investorName,
                              );
                              final chatDoc =
                                  await ChatService.chatRef(chatId).get();
                              if (!context.mounted) return;
                              final chat = chatDoc.data() ?? {};
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chatId,
                                    title: ChatService.displayTitle(
                                      chat,
                                      userId,
                                    ),
                                    subtitle: ChatService.displaySubtitle(chat),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not open chat: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.chat_rounded),
                          label: const Text('Message Entrepreneur'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (widget.sendInterestOnLoad && showInterestConfirmed) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Back to Startups'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
