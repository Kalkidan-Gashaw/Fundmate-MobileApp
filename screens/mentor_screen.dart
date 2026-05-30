import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'chat_screen.dart';
import 'services/chat_service.dart';
import 'widgets/fundmate_app_bar.dart';
import 'widgets/theme_toggle_button.dart';
import 'widgets/chats_tab.dart';
import 'widgets/unread_badge.dart';
import 'theme/app_colors.dart';

class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final TabController _tabController;

  String get userId => FirebaseAuth.instance.currentUser!.uid;
  String get userName =>
      FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'Mentor';

  Stream<QuerySnapshot> get _allRequestsStream => FirebaseFirestore.instance
      .collection('mentorship_requests')
      .where('mentorId', isEqualTo: userId)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    setState(() => _isLoading = true);
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('mentorship_requests')
          .doc(requestId);
      final requestDoc = await requestRef.get();
      final requestData = requestDoc.data();

      await requestRef.update({'status': status});

      if (status == 'accepted' && requestData != null) {
        await ChatService.ensureChatRoomFromRequest(requestId, requestData);
        _tabController.animateTo(2);
      }

      _showSnackbar(
        status == 'accepted' ? 'Request accepted' : 'Request rejected',
        status == 'accepted' ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openMenteeChat(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    setState(() => _isLoading = true);
    try {
      await ChatService.ensureChatRoomFromRequest(requestId, data);
      if (!mounted) return;
      await _openChat(requestId, {
        'chatType': 'mentorship',
        'mentorName': data['mentorName'],
        'entrepreneurName': data['entrepreneurName'],
        'startupName': data['startupName'],
        'mentorId': data['mentorId'],
        'entrepreneurId': data['entrepreneurId'],
      });
    } catch (e) {
      _showSnackbar('Could not open chat: $e', Colors.red);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openChat(String chatId, Map<String, dynamic> chat) async {
    if (chat['chatType'] == 'mentorship') {
      final requestDoc = await FirebaseFirestore.instance
          .collection('mentorship_requests')
          .doc(chatId)
          .get();
      if (requestDoc.exists) {
        await ChatService.ensureChatRoomFromRequest(chatId, requestDoc.data()!);
      }
    }

    if (!mounted) return;
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

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return 'Date unavailable';
  }

  int _countByStatus(List<QueryDocumentSnapshot> docs, String status) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == status;
    }).length;
  }

  List<QueryDocumentSnapshot> _filterByStatus(
    List<QueryDocumentSnapshot> docs,
    String status,
  ) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FundMateAppBar(
        title: 'Mentor Dashboard',
        subtitle: 'FundMate',
        leadingIcon: Icons.school_rounded,
        actions: [
          FundMateAppBar.actionButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to roles',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
              );
            },
          ),
          FundMateAppBar.actionButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
          ),
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
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName! 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review requests and mentor active founders',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _allRequestsStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final pending = _countByStatus(docs, 'pending');
                  final active = _countByStatus(docs, 'accepted');
                  final completed = _countByStatus(docs, 'rejected');

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            pending.toString(),
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Active',
                            active.toString(),
                            Icons.people_outline,
                            const Color(0xFF26D0CE),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Completed',
                            completed.toString(),
                            Icons.task_alt,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ChatService.chatsForUser(userId),
                  builder: (context, chatsSnapshot) {
                    final chats = chatsSnapshot.data?.docs
                            .map((d) => d.data())
                            .toList() ??
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
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        const Tab(
                          icon: Icon(Icons.pending_actions, size: 20),
                          text: 'Pending',
                        ),
                        const Tab(
                          icon: Icon(Icons.handshake_outlined, size: 20),
                          text: 'Mentorship',
                        ),
                        BadgedTab(
                          icon: Icons.chat,
                          label: 'Chats',
                          badgeCount: unreadTotal,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _allRequestsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'Could not load mentorship data',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];
                    final pending = _filterByStatus(allDocs, 'pending');
                    final activeMentees = _filterByStatus(allDocs, 'accepted');

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRequestsList(
                          requests: pending,
                          emptyIcon: Icons.inbox_outlined,
                          emptyTitle: 'No pending requests',
                          emptySubtitle:
                              'New mentorship requests will appear here',
                          itemBuilder: (doc) => _buildRequestCard(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        ),
                        _buildRequestsList(
                          requests: activeMentees,
                          emptyIcon: Icons.people_outline,
                          emptyTitle: 'No mentorships yet',
                          emptySubtitle:
                              'Accept a request to mentor a founder and see their startup work here',
                          itemBuilder: (doc) => _buildMenteeCard(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          ),
                        ),
                        ChatsTab(
                          userId: userId,
                          isLoading: _isLoading,
                          onRefresh: _refresh,
                          onOpenChat: _openChat,
                          emptySubtitle:
                              'Your mentorship conversations appear here after you accept a request.',
                          emptyActionLabel: 'View requests',
                          onEmptyAction: () => _tabController.animateTo(0),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF26D0CE),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestsList({
    required List<QueryDocumentSnapshot> requests,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required Widget Function(QueryDocumentSnapshot doc) itemBuilder,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (requests.isEmpty) {
      return RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            Icon(emptyIcon, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Center(
              child: Text(
                emptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  emptySubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: requests.length,
        itemBuilder: (context, index) => itemBuilder(requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> data) {
    final entrepreneurName = data['entrepreneurName'] ?? 'Entrepreneur';
    final startupName = data['startupName'] ?? 'Startup';
    final message = data['message'] ?? 'No message provided';
    final date = _formatDate(data['createdAt']);
    final startupId = data['startupId'] as String?;

    return FutureBuilder<DocumentSnapshot?>(
      future: _loadStartup(startupId),
      builder: (context, startupSnap) {
        final startup = startupSnap.data?.data() as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPersonHeader(
                context,
                name: entrepreneurName,
                subtitle: startupName,
                trailing: _buildDateChip(context, date),
                icon: Icons.person,
              ),
              if (startup != null) ...[
                const SizedBox(height: 12),
                _buildStartupWorkSection(context, startup),
              ],
              const SizedBox(height: 12),
              _buildMessageBox(context, label: 'Request message', message: message),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _updateRequestStatus(requestId, 'accepted'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _updateRequestStatus(requestId, 'rejected'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenteeCard(String requestId, Map<String, dynamic> data) {
    final entrepreneurName = data['entrepreneurName'] ?? 'Entrepreneur';
    final startupName = data['startupName'] ?? 'Startup';
    final message = data['message'] ?? 'No message provided';
    final date = _formatDate(data['createdAt']);
    final startupId = data['startupId'] as String?;

    return FutureBuilder<DocumentSnapshot?>(
      future: _loadStartup(startupId),
      builder: (context, startupSnap) {
        final startup = startupSnap.data?.data() as Map<String, dynamic>?;
        final displayStartupName =
            startup?['name'] as String? ?? startupName;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(
            context,
            borderColor: AppColors.accent.withValues(alpha: 0.45),
            borderWidth: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPersonHeader(
                context,
                name: entrepreneurName,
                subtitle: 'Mentoring · $displayStartupName',
                trailing: _buildStatusChip(context, 'Active'),
                icon: Icons.rocket_launch,
              ),
              const SizedBox(height: 12),
              Text(
                'Their work',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              if (startupSnap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (startup != null)
                _buildStartupWorkSection(context, startup)
              else
                _buildMessageBox(
                  context,
                  label: 'Startup',
                  message: startupName,
                ),
              const SizedBox(height: 12),
              _buildMessageBox(
                context,
                label: 'Mentorship focus',
                message: message,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Mentoring since $date',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _openMenteeChat(requestId, data),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Send message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
      },
    );
  }

  Future<DocumentSnapshot?> _loadStartup(String? startupId) async {
    if (startupId == null || startupId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .get();
    return doc.exists ? doc : null;
  }

  BoxDecoration _cardDecoration(
    BuildContext context, {
    Color? borderColor,
    double borderWidth = 1,
  }) {
    final fm = context.fundMate;
    return BoxDecoration(
      color: fm.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? fm.cardBorder, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildPersonHeader(
    BuildContext context, {
    required String name,
    required String subtitle,
    required Widget trailing,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: scheme.primary),
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildDateChip(BuildContext context, String date) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(date, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildMessageBox(
    BuildContext context, {
    required String label,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fundMate.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStartupWorkSection(
    BuildContext context,
    Map<String, dynamic> startup,
  ) {
    final sector = startup['sector']?.toString() ?? '—';
    final funding = startup['fundingNeeded'];
    final description = startup['description']?.toString().trim() ?? '';
    final name = startup['name']?.toString() ?? 'Startup';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fundMate.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fundMate.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTag(context, sector),
              if (funding != null)
                _buildTag(
                  context,
                  '\$$funding funding goal',
                  icon: Icons.payments_outlined,
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
