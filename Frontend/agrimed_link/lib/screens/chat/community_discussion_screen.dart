import 'package:flutter/material.dart';
import '../../models/community_model.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'private_chat_screen.dart';

class CommunityDiscussionScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunityDiscussionScreen({
    super.key,
    required this.community,
  });

  @override
  State<CommunityDiscussionScreen> createState() => _CommunityDiscussionScreenState();
}

class _CommunityDiscussionScreenState extends State<CommunityDiscussionScreen> {
  late CommunityModel _community;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _currentUserId = '';
  UserModel? _currentUser;

  final List<String> _quickTopics = [
    '🌱 Cultivation Advice',
    '🔍 Pest / Disease Alert',
    '💰 Market Price Check',
    '🚜 Drip Irrigation Question',
    '📦 Bulk Harvest Available',
  ];

  @override
  void initState() {
    super.initState();
    _community = widget.community;
    _initUserAndMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initUserAndMessages() async {
    _currentUser = await AuthService.getStoredUser();
    if (_currentUser != null) {
      _currentUserId = _currentUser!.id;
    }
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final list = await ChatService.instance.getCommunityMessages(_community.id);
      if (mounted) {
        setState(() {
          _messages = list;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _messageController.text;
    if (text.trim().isEmpty) return;

    if (presetText == null) {
      _messageController.clear();
    }

    setState(() => _isSending = true);
    try {
      final sent = await ChatService.instance.sendCommunityMessage(_community.id, text);
      if (mounted) {
        setState(() {
          _messages.add(sent);
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post message: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _toggleJoin() async {
    final willJoin = !_community.isJoined;
    setState(() {
      _community = _community.copyWith(
        isJoined: willJoin,
        membersCount: willJoin ? _community.membersCount + 1 : (_community.membersCount > 1 ? _community.membersCount - 1 : 1),
      );
    });

    if (willJoin) {
      await ChatService.instance.joinCommunity(_community.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined "${_community.name}"!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } else {
      await ChatService.instance.leaveCommunity(_community.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left "${_community.name}".'),
            backgroundColor: Colors.grey.shade700,
          ),
        );
      }
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F5),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _community.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_community.category} • ${_community.membersCount} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _toggleJoin,
              icon: Icon(
                _community.isJoined ? Icons.check_circle_rounded : Icons.group_add_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                _community.isJoined ? 'Joined' : 'Join',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _community.isJoined
                    ? Colors.white.withOpacity(0.25)
                    : AppTheme.accentAmber,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh messages',
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Community Description Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.green.shade100, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.secondaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _community.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.darkText,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Discussion Message List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No community messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Be the first to start the discussion!',
                              style: TextStyle(fontSize: 13, color: AppTheme.lightText),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.isMine(_currentUserId);
                          return _buildMessageItem(msg, isMe);
                        },
                      ),
          ),

          // Quick Topic Chips
          Container(
            height: 42,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickTopics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final topic = _quickTopics[index];
                return ActionChip(
                  label: Text(
                    topic,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  backgroundColor: AppTheme.lightGreen,
                  side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    _messageController.text = topic;
                  },
                );
              },
            ),
          ),

          // Bottom Interactive Chatbox
          _buildChatbox(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessageModel msg, bool isMe) {
    final roleColor = _getRoleColor(msg.senderRole);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              if (!isMe) {
                _openPrivateChatWith(
                  partnerId: msg.senderId,
                  partnerName: msg.senderName ?? 'User',
                  partnerRole: msg.senderRole ?? 'farmer',
                );
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: roleColor.withOpacity(0.15),
              child: Text(
                (msg.senderName?.isNotEmpty == true ? msg.senderName![0] : 'U').toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: roleColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Message Content Box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFE8F5E9) : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topLeft: const Radius.circular(4),
                ),
                border: Border.all(
                  color: isMe ? Colors.green.shade200 : Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name + role badge + timestamp
                  Row(
                    children: [
                      Text(
                        isMe ? 'You' : (msg.senderName ?? 'Agri Member'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: roleColor.withOpacity(0.3), width: 0.8),
                        ),
                        child: Text(
                          (msg.senderRole ?? 'member').toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: roleColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(msg.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Message text
                  Text(
                    msg.content,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF2C3E50),
                      height: 1.35,
                    ),
                  ),

                  // Action to message sender directly if not me
                  if (!isMe) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () {
                          _openPrivateChatWith(
                            partnerId: msg.senderId,
                            partnerName: msg.senderName ?? 'User',
                            partnerRole: msg.senderRole ?? 'farmer',
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mark_chat_unread_rounded,
                                size: 13, color: AppTheme.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              'Private Message',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPrivateChatWith({
    required String partnerId,
    required String partnerName,
    required String partnerRole,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrivateChatScreen(
          partnerId: partnerId,
          partnerName: partnerName,
          partnerRole: partnerRole,
        ),
      ),
    );
  }

  Widget _buildChatbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.green.shade200, width: 1),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Share with the community...',
                    hintStyle: TextStyle(fontSize: 13.5, color: AppTheme.lightText),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isSending ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}
