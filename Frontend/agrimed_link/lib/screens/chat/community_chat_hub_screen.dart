import 'package:flutter/material.dart';
import '../../models/community_model.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'community_discussion_screen.dart';
import 'private_chat_screen.dart';

class CommunityChatHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const CommunityChatHubScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<CommunityChatHubScreen> createState() => _CommunityChatHubScreenState();
}

class _CommunityChatHubScreenState extends State<CommunityChatHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<CommunityModel> _communities = [];
  List<ChatConversationModel> _inbox = [];
  bool _isLoadingCommunities = true;
  bool _isLoadingInbox = true;

  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Medicinal Crops',
    'Agronomy & Protection',
    'Marketplace & Trade',
    'Agri-Tech & Tools',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadCommunities(),
      _loadInbox(),
    ]);
  }

  Future<void> _loadCommunities() async {
    setState(() => _isLoadingCommunities = true);
    try {
      final list = await ChatService.instance.getCommunities(
        category: _selectedCategory,
        search: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _communities = list;
          _isLoadingCommunities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCommunities = false);
    }
  }

  Future<void> _loadInbox() async {
    setState(() => _isLoadingInbox = true);
    try {
      final list = await ChatService.instance.getInbox();
      if (mounted) {
        setState(() {
          _inbox = list;
          _isLoadingInbox = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInbox = false);
    }
  }

  int get _totalUnreadCount {
    return _inbox.fold(0, (sum, c) => sum + c.unreadCount);
  }

  // ── Create Community Dialog ───────────────────────────────────────────────

  void _showCreateCommunityDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Medicinal Crops';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_add_rounded, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create New Community',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Community Name',
                  hintText: 'e.g. Organic Aloe & Herb Growers',
                  prefixIcon: const Icon(Icons.title_rounded, color: AppTheme.secondaryGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Topic Category',
                  prefixIcon: const Icon(Icons.category_rounded, color: AppTheme.secondaryGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                ),
                items: _categories
                    .where((c) => c != 'All')
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Share the purpose, guidelines, and focus of your community...',
                  prefixIcon: const Icon(Icons.description_rounded, color: AppTheme.secondaryGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a community name'),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            final created = await ChatService.instance.createCommunity(
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              category: category,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadCommunities();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CommunityDiscussionScreen(community: created),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create community: $e'),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Launch Community',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── New Message / Contact Directory Dialog ───────────────────────────────

  void _showStartPrivateChatDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filterRole = 'all';
        String searchTxt = '';
        List<UserModel> users = [];
        bool loading = true;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void fetchUsers() async {
              setSheetState(() => loading = true);
              final u = await ChatService.instance.getAvailableUsers(
                query: searchTxt,
                role: filterRole,
              );
              setSheetState(() {
                users = u;
                loading = false;
              });
            }

            if (loading && users.isEmpty) {
              fetchUsers();
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Start Private Chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search bar
                  TextField(
                    onChanged: (val) {
                      searchTxt = val;
                      fetchUsers();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search growers, advisors, suppliers...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.secondaryGreen),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF9FBF9),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Role filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['all', 'farmer', 'advisor', 'supplier', 'customer'].map((role) {
                        final isSel = filterRole == role;
                        final label = role == 'all'
                            ? 'All Roles'
                            : '${role[0].toUpperCase()}${role.substring(1)}s';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSel,
                            selectedColor: AppTheme.primaryGreen,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppTheme.darkText,
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                filterRole = role;
                                fetchUsers();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Users list
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                          )
                        : users.isEmpty
                            ? Center(
                                child: Text(
                                  'No users found matching query',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.separated(
                                itemCount: users.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final u = users[idx];
                                  final roleColor = _getRoleColor(u.role);

                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: roleColor.withOpacity(0.15),
                                      child: Text(
                                        u.displayName.isNotEmpty
                                            ? u.displayName[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      u.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${u.email} • ${u.phoneNumber ?? ''}',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                    trailing: Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        u.role.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PrivateChatScreen(
                                            partnerId: u.id,
                                            partnerName: u.displayName,
                                            partnerRole: u.role,
                                            partnerPhoneNumber: u.phoneNumber,
                                          ),
                                        ),
                                      ).then((_) => _loadInbox());
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'advisor':
        return Colors.teal.shade700;
      case 'farmer':
        return AppTheme.primaryGreen;
      case 'supplier':
        return Colors.indigo.shade700;
      case 'admin':
        return AppTheme.accentAmber;
      case 'investor':
        return Colors.purple.shade700;
      case 'customer':
      default:
        return Colors.blueGrey.shade700;
    }
  }

  // ── Build UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        title: const Text(
          'AgriMed Network & Chats',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            const Tab(
              icon: Icon(Icons.groups_rounded, size: 20),
              text: 'Communities',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _totalUnreadCount > 0,
                label: Text('$_totalUnreadCount'),
                backgroundColor: AppTheme.errorRed,
                child: const Icon(Icons.mark_chat_unread_rounded, size: 20),
              ),
              text: 'Private Inbox',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCommunitiesTab(),
          _buildInboxTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showCreateCommunityDialog,
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Community',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _showStartPrivateChatDialog,
              backgroundColor: AppTheme.secondaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_rounded),
              label: const Text(
                'New Message',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  // ── Tab 1: Communities ───────────────────────────────────────────────────

  Widget _buildCommunitiesTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _loadCommunities(),
            decoration: InputDecoration(
              hintText: 'Search communities & discussion groups...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.secondaryGreen),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _loadCommunities();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF3F7F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Category Filter Chips
        Container(
          height: 46,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSel = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSel,
                selectedColor: AppTheme.primaryGreen,
                backgroundColor: const Color(0xFFEBF3EE),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : AppTheme.darkText,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = cat);
                    _loadCommunities();
                  }
                },
              );
            },
          ),
        ),

        const Divider(height: 1, thickness: 1),

        // Community List
        Expanded(
          child: _isLoadingCommunities
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                )
              : _communities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No communities found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap "Create Community" below to start one!',
                            style: TextStyle(color: AppTheme.lightText, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCommunities,
                      color: AppTheme.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                        itemCount: _communities.length,
                        itemBuilder: (context, index) {
                          final comm = _communities[index];
                          return _buildCommunityCard(comm);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCommunityCard(CommunityModel comm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommunityDiscussionScreen(community: comm),
              ),
            ).then((_) => _loadCommunities());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: AppTheme.primaryGreen,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comm.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  comm.category,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.people_rounded, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${comm.membersCount} members',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (comm.isJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 12, color: AppTheme.primaryGreen),
                            SizedBox(width: 3),
                            Text(
                              'Joined',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  comm.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF55605A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Created by ${comm.creatorName ?? 'Community Organizer'}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.lightText),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Forum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppTheme.primaryGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 2: Private Inbox ─────────────────────────────────────────────────

  Widget _buildInboxTab() {
    if (_isLoadingInbox) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (_inbox.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline_rounded, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Your Inbox is Empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "New Message" to chat directly with farmers, suppliers & advisors.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.lightText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      color: AppTheme.primaryGreen,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: _inbox.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final conv = _inbox[index];
          final roleColor = _getRoleColor(conv.partnerRole);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: conv.unreadCount > 0 ? Colors.green.shade300 : Colors.grey.shade200,
                width: conv.unreadCount > 0 ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivateChatScreen(
                      partnerId: conv.partnerId,
                      partnerName: conv.partnerName,
                      partnerRole: conv.partnerRole,
                      partnerPhoneNumber: conv.partnerPhoneNumber,
                    ),
                  ),
                ).then((_) => _loadInbox());
              },
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor.withOpacity(0.15),
                    child: Text(
                      conv.partnerName.isNotEmpty ? conv.partnerName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: roleColor,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      conv.partnerName,
                      style: TextStyle(
                        fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      conv.partnerRole.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        conv.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          color: conv.unreadCount > 0 ? Colors.black87 : AppTheme.lightText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatInboxTime(conv.lastMessageTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: conv.unreadCount > 0 ? AppTheme.primaryGreen : AppTheme.lightText,
                        fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: conv.unreadCount > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${conv.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );

        },
      ),
    );
  }

  String _formatInboxTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
