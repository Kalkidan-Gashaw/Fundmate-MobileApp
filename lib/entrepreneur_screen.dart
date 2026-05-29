import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './main.dart';
import './chat_screen.dart';
import 'services/chat_service.dart';
import 'widgets/fundmate_app_bar.dart';
import 'widgets/theme_toggle_button.dart';
import 'widgets/chats_tab.dart';
import 'widgets/unread_badge.dart';
import 'theme/app_colors.dart';

class EntrepreneurScreen extends StatefulWidget {
  const EntrepreneurScreen({super.key});

  @override
  State<EntrepreneurScreen> createState() => _EntrepreneurScreenState();
}

class _EntrepreneurScreenState extends State<EntrepreneurScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _fundingController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _mentorMessageController = TextEditingController();

  late final TabController _tabController;

  bool _isLoading = false;
  bool _showCreateForm = false;
  String? _selectedMentorId;
  List<Map<String, dynamic>> _mentorsList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _sectorController.dispose();
    _fundingController.dispose();
    _descriptionController.dispose();
    _mentorMessageController.dispose();
    super.dispose();
  }

  String get userId => FirebaseAuth.instance.currentUser!.uid;
  String get userName => FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'User';

  Stream<QuerySnapshot> get _myStartupsStream => FirebaseFirestore.instance
      .collection('startups')
      .where('entrepreneurId', isEqualTo: userId)
      .snapshots();

  Stream<QuerySnapshot> get _myMentorshipRequestsStream => FirebaseFirestore.instance
      .collection('mentorship_requests')
      .where('entrepreneurId', isEqualTo: userId)
      .snapshots();

  List<QueryDocumentSnapshot> _sortStartupsNewestFirst(List<QueryDocumentSnapshot> docs) {
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<QueryDocumentSnapshot> _sortMentorshipNewestFirst(
      List<QueryDocumentSnapshot> docs) {
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return 'Date unavailable';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF26D0CE);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Mentor Accepted';
      case 'rejected':
        return 'Declined';
      default:
        return 'Pending';
    }
  }

  Future<void> _createStartup() async {
  print('Create startup pressed');  // ADD THIS
  
  if (_nameController.text.isEmpty ||
      _sectorController.text.isEmpty ||
      _fundingController.text.isEmpty ||
      _descriptionController.text.trim().isEmpty) {
    _showSnackbar('Please fill all fields including description', Colors.red);
    return;
  }

  setState(() => _isLoading = true);
  try {
    print('Saving to Firestore...');  // ADD THIS
    
    final docRef = await FirebaseFirestore.instance.collection('startups').add({
      'name': _nameController.text.trim(),
      'sector': _sectorController.text.trim(),
      'description': _descriptionController.text.trim(),
      'fundingNeeded': int.parse(_fundingController.text.trim()),
      'entrepreneurId': userId,
      'interestedInvestors': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    print('Saved with ID: ${docRef.id}');  // ADD THIS
    
    _nameController.clear();
    _sectorController.clear();
    _fundingController.clear();
    _descriptionController.clear();
    setState(() => _showCreateForm = false);
    _showSnackbar('Startup created successfully!', Colors.green);
  } catch (e) {
    print('Error: $e');  // ADD THIS
    _showSnackbar('Error: ${e.toString()}', Colors.red);
  }
  setState(() => _isLoading = false);
}

  Future<void> _deleteStartup(String startupId) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('startups').doc(startupId).delete();
      _showSnackbar('Startup deleted', Colors.green);
    } catch (e) {
      _showSnackbar('Error deleting', Colors.red);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMentors() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'mentor')
        .get();
    
    setState(() {
      _mentorsList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Mentor',
          'email': data['email'] ?? '',
        };
      }).toList();
    });
  }

  Future<void> _requestMentorship(String startupId, String startupName) async {
    await _loadMentors();
    
    if (_mentorsList.isEmpty) {
      _showSnackbar('No mentors available', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Request Mentorship'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select a mentor:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMentorId,
                    hint: const Text('Choose mentor'),
                    items: _mentorsList.map((mentor) {
                      return DropdownMenuItem<String>(
                        value: mentor['id'] as String,
                        child: Text('${mentor['name']} (${mentor['email']})'),
                      );
                    }).toList(),
                    onChanged: (value) => setDialogState(() => _selectedMentorId = value),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mentorMessageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'What do you need help with?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _mentorMessageController.clear();
                  _selectedMentorId = null;
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_selectedMentorId == null) {
                    _showSnackbar('Please select a mentor', Colors.red);
                    return;
                  }
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  
                  final selectedMentor = _mentorsList.firstWhere((m) => m['id'] == _selectedMentorId);
                  
                  await FirebaseFirestore.instance.collection('mentorship_requests').add({
                    'startupId': startupId,
                    'startupName': startupName,
                    'entrepreneurId': userId,
                    'entrepreneurName': userName,
                    'mentorId': _selectedMentorId,
                    'mentorName': selectedMentor['name'],
                    'message': _mentorMessageController.text.isEmpty ? 'Would like mentorship' : _mentorMessageController.text,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                  _mentorMessageController.clear();
                  _selectedMentorId = null;
                  _showSnackbar('Mentorship request sent!', Colors.green);
                  _tabController.animateTo(1);
                  setState(() => _isLoading = false);
                },
                child: const Text('Send Request'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  Future<void> _openMentorChat(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final status = data['status'] as String? ?? 'pending';
    if (status != 'accepted') {
      _showSnackbar(
        'Chat opens after your mentor accepts the request',
        Colors.orange,
      );
      return;
    }

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

  Future<void> _openInvestorChat(
    String startupId,
    String investorId,
    String investorName,
  ) async {
    setState(() => _isLoading = true);
    try {
      final chatId = await ChatService.ensureInvestmentChatFromStartup(
        startupId,
        investorId,
        investorName,
      );
      if (!mounted) return;
      final chatDoc = await ChatService.chatRef(chatId).get();
      final chat = chatDoc.data() ?? {};
      await _openChat(chatId, chat);
    } catch (e) {
      _showSnackbar('Could not open chat: $e', Colors.red);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showInterestedInvestors(
    List<dynamic> investorIds,
    String startupId,
    String startupName,
  ) async {
    if (investorIds.isEmpty) {
      _showSnackbar('No investors interested yet', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final investors = <Map<String, String>>[];
      for (final id in investorIds) {
        final investorId = id.toString();
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(investorId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          investors.add({
            'id': investorId,
            'name': data['name']?.toString() ?? 'Investor',
            'email': data['email']?.toString() ?? '',
          });
        } else {
          investors.add({
            'id': investorId,
            'name': 'Investor',
            'email': investorId,
          });
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Interested Investors',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  startupName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: investors.length,
                    itemBuilder: (context, index) {
                      final investor = investors[index];
                      final fm = context.fundMate;
                      final scheme = Theme.of(context).colorScheme;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: fm.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fm.cardBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: fm.avatarBg,
                              child: Icon(
                                Icons.account_balance_wallet,
                                color: scheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    investor['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (investor['email']!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      investor['email']!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.chat_rounded,
                                  color: Theme.of(context).colorScheme.primary),
                              tooltip: 'Message investor',
                              onPressed: () {
                                Navigator.pop(context);
                                _openInvestorChat(
                                  startupId,
                                  investor['id']!,
                                  investor['name']!,
                                );
                              },
                            ),
                            Icon(Icons.favorite,
                                color: Colors.red.shade400, size: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar('Could not load investors: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FundMateAppBar(
        title: 'Entrepreneur Dashboard',
        subtitle: 'FundMate',
        leadingIcon: Icons.rocket_launch_rounded,
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
      resizeToAvoidBottomInset: true,
      body: _showCreateForm ? _buildCreateStartupView() : _buildDashboardView(),
    );
  }

  Widget _buildCreateStartupView() {
    final scheme = Theme.of(context).colorScheme;
    final fm = context.fundMate;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _showCreateForm = false),
                icon: Icon(Icons.arrow_back, color: scheme.onSurface),
              ),
              Expanded(
                child: Text(
                  'Create New Startup',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: scheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fm.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: fm.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Startup Name',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sectorController,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Sector (e.g., FinTech, HealthTech)',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fundingController,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Funding Needed (\$)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Startup Description',
                    hintText:
                        'Describe your business, traction, and funding goals...',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _showCreateForm = false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: scheme.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createStartup,
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName! 👋',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Build your startup, find investors, and get mentorship',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _myStartupsStream,
          builder: (context, startupSnapshot) {
            int startupCount = startupSnapshot.data?.docs.length ?? 0;
            int totalInterests = 0;
            if (startupSnapshot.hasData) {
              for (var doc in startupSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final interests = data['interestedInvestors'] as List? ?? [];
                totalInterests += interests.length;
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _myMentorshipRequestsStream,
              builder: (context, mentorshipSnapshot) {
                int acceptedMentors = 0;
                if (mentorshipSnapshot.hasData) {
                  for (var doc in mentorshipSnapshot.data!.docs) {
                    final status =
                        (doc.data() as Map<String, dynamic>)['status'] as String? ??
                            'pending';
                    if (status == 'accepted') acceptedMentors++;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Startups',
                          startupCount.toString(),
                          Icons.business,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Investors',
                          totalInterests.toString(),
                          Icons.favorite,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Mentors',
                          acceptedMentors.toString(),
                          Icons.school,
                          const Color(0xFF26D0CE),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showCreateForm = true),
            icon: const Icon(Icons.add),
            label: const Text('Create New Startup'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ChatService.chatsForUser(userId),
            builder: (context, chatsSnapshot) {
              final chats =
                  chatsSnapshot.data?.docs.map((d) => d.data()).toList() ?? [];
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
                    icon: Icon(Icons.business, size: 20),
                    text: 'Startups',
                  ),
                  const Tab(
                    icon: Icon(Icons.school, size: 20),
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
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStartupsTab(),
              _buildMentorshipTab(),
              ChatsTab(
                userId: userId,
                isLoading: _isLoading,
                onRefresh: _refresh,
                onOpenChat: _openChat,
                emptySubtitle:
                    'Message mentors or investors after mentorship is accepted or they show interest.',
                emptyActionLabel: 'Go to Mentorship',
                onEmptyAction: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartupsTab() {
    return StreamBuilder<QuerySnapshot>(
              stream: _myStartupsStream,
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
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Could not load startups',
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
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_center,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No startups yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Create New Startup" to get started',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                final startups = _sortStartupsNewestFirst(snapshot.data!.docs);
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: startups.length,
                  itemBuilder: (context, index) {
                    final doc = startups[index];
                    final startup = doc.data() as Map<String, dynamic>;
                    final interestedInvestors = startup['interestedInvestors'] as List? ?? [];
                    final fm = context.fundMate;

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  startup['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showInterestedInvestors(
                                  interestedInvestors,
                                  doc.id,
                                  startup['name'] ?? 'Startup',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${interestedInvestors.length} interested',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (interestedInvestors.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 14,
                                          color: Colors.green.shade700,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  startup['sector'],
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${startup['fundingNeeded']} needed',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          if ((startup['description'] as String?)?.trim().isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 10),
                            Text(
                              startup['description'],
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    height: 1.4,
                                  ),
                            ),
                          ],
                          if (interestedInvestors.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _showInterestedInvestors(
                                  interestedInvestors,
                                  doc.id,
                                  startup['name'] ?? 'Startup',
                                ),
                                icon: const Icon(Icons.people_outline, size: 18),
                                label: const Text('View interested investors'),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _requestMentorship(doc.id, startup['name']),
                                  icon: const Icon(Icons.school, size: 18),
                                  label: const Text('Request Mentorship'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _deleteStartup(doc.id),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
  }

  Widget _buildMentorshipTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _myMentorshipRequestsStream,
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
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load mentorship requests',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No mentorship requests yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request mentorship from a startup card to track mentor responses here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }

        final requests = _sortMentorshipNewestFirst(snapshot.data!.docs);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? 'pending';
            final mentorName = data['mentorName'] ?? 'Mentor';
            final startupName = data['startupName'] ?? 'Startup';
            final message = data['message'] ?? '';
            final date = _formatDate(data['createdAt']);

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
                        child: Icon(Icons.school, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mentorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              startupName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (status == 'accepted') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26D0CE).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.teal.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$mentorName is mentoring your startup!',
                              style: TextStyle(
                                color: Colors.teal.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _openMentorChat(doc.id, data),
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('Message Mentor'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (status == 'rejected')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$mentorName declined this request.',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  if (status == 'pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Waiting for $mentorName to respond...',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fm.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fm.cardBorder),
                    ),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Requested $date',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final fm = context.fundMate;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fm.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fm.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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