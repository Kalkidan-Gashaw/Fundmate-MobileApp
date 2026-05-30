import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'package:fundmate_app/main.dart';
import 'nda_sign_screen.dart';
import 'package:fundmate_app/services/chat_service.dart';
import 'package:fundmate_app/services/nda_service.dart';
import 'package:fundmate_app/widgets/chats_tab.dart';
import 'package:fundmate_app/widgets/fundmate_app_bar.dart';
import 'package:fundmate_app/widgets/theme_toggle_button.dart';
import 'package:fundmate_app/widgets/unread_badge.dart';
import 'package:fundmate_app/theme/app_colors.dart';

class InvestorScreen extends StatefulWidget {
  const InvestorScreen({super.key});

  @override
  State<InvestorScreen> createState() => _InvestorScreenState();
}

class _InvestorScreenState extends State<InvestorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get userId => FirebaseAuth.instance.currentUser!.uid;
  String get userName =>
      FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Investor';

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  Future<void> _openChat(String chatId, Map<String, dynamic> chat) async {
    try {
      await ChatService.markAsRead(chatId, userId);
    } catch (_) {}
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          title: ChatService.displayTitle(chat, userId),
          subtitle: ChatService.displaySubtitle(chat),
        ),
      ),
    );
  }

  Future<void> _messageEntrepreneur(String startupId) async {
    setState(() => _isLoading = true);
    try {
      final chatId = await ChatService.ensureInvestmentChatFromStartup(
        startupId,
        userId,
        userName,
      );
      if (!mounted) return;
      final chatDoc = await ChatService.chatRef(chatId).get();
      await _openChat(chatId, chatDoc.data() ?? {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open chat: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openNdaSign(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NdaSignScreen(
          startupId: '',
          startupName: 'Startup',
        ),
      ),
    );
  }

  void _onShowInterest(
    BuildContext context,
    String startupId,
    String startupName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NdaSignScreen(
          startupId: startupId,
          startupName: startupName,
        ),
      ),
    );
  }

  Widget _buildNdaBanner(BuildContext context, bool hasSigned) {
    if (hasSigned) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'NDA signed — you can view full startup descriptions',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'NDA required',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sign the Non-Disclosure Agreement before viewing confidential startup details.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openNdaSign(context),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Sign NDA Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartupsTab(bool hasSigned) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('startups').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error loading startups: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final startups = snapshot.data?.docs ?? [];
        if (startups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'No startups available yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: startups.length,
          itemBuilder: (context, index) {
            final doc = startups[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name']?.toString() ?? 'Startup';
            final sector = data['sector']?.toString() ?? '';
            final funding = data['fundingNeeded']?.toString() ?? '0';
            final interested =
                (data['interestedInvestors'] as List?)?.contains(userId) ??
                    false;
            final fm = context.fundMate;
            final scheme = Theme.of(context).colorScheme;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fm.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: fm.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: fm.shadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: fm.avatarBg,
                        child: Icon(
                          Icons.rocket_launch,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (sector.isNotEmpty)
                              Text(
                                sector,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (interested)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Interested',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\$$funding needed',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasSigned ? Icons.lock_open : Icons.lock_outline,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hasSigned
                              ? 'Tap Show Interest to view full description'
                              : 'Full description locked until NDA is signed',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _onShowInterest(context, doc.id, name),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Show Interest'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (interested) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _messageEntrepreneur(doc.id),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('Message Entrepreneur'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FundMateAppBar(
        title: 'Investor Dashboard',
        subtitle: 'Discover startups',
        leadingIcon: Icons.trending_up_rounded,
        actions: [
          const ThemeToggleButton(),
          FundMateAppBar.actionButton(
            icon: Icons.logout_rounded,
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: NdaService.signatureStream(userId),
        builder: (context, ndaSnapshot) {
          final hasSigned = ndaSnapshot.hasData &&
              ndaSnapshot.data!.exists &&
              ndaSnapshot.data!.data()?['signed'] == true;

          return Column(
            children: [
              _buildNdaBanner(context, hasSigned),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ChatService.chatsForUser(userId),
                builder: (context, chatsSnapshot) {
                  final chats =
                      chatsSnapshot.data?.docs.map((d) => d.data()).toList() ??
                          [];
                  final unreadTotal =
                      ChatService.totalUnreadFromChats(chats, userId);

                  final scheme = Theme.of(context).colorScheme;
                  return TabBar(
                    controller: _tabController,
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    tabs: [
                      const Tab(
                        icon: Icon(Icons.business, size: 20),
                        text: 'Startups',
                      ),
                      Tab(
                        child: BadgedTab(
                          icon: Icons.chat,
                          label: 'Chats',
                          badgeCount: unreadTotal,
                        ),
                      ),
                    ],
                  );
                },
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStartupsTab(hasSigned),
                    ChatsTab(
                      userId: userId,
                      isLoading: _isLoading,
                      onRefresh: _refresh,
                      onOpenChat: _openChat,
                      emptyTitle: 'No conversations yet',
                      emptySubtitle:
                          'After you show interest in a startup, chat with the entrepreneur here.',
                      emptyActionLabel: 'Explore startups',
                      onEmptyAction: () => _tabController.animateTo(0),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
