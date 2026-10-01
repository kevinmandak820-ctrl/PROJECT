import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/community_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_conversation_model.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  // Test and offline mock store
  static bool forceMockMode = false;
  final List<CommunityModel> _mockCommunities = [];
  final Map<String, List<ChatMessageModel>> _mockCommunityMessages = {};
  final Map<String, List<ChatMessageModel>> _mockPrivateMessages = {};
  bool _initializedMocks = false;

  void _initDefaultMocks() {
    if (_initializedMocks) return;
    _initializedMocks = true;

    _mockCommunities.addAll([
      CommunityModel(
        id: 'comm-1',
        name: '🌿 Medicinal Herbs & Botanicals',
        description:
            'A collaborative forum for cultivating, harvesting, and processing organic medicinal plants including Aloe Vera, Ginseng, Moringa, and Ashwagandha.',
        category: 'Medicinal Crops',
        icon: 'eco',
        creatorId: 'farmer-demo-id',
        creatorName: 'Elena Vance (Farmer)',
        membersCount: 42,
        isJoined: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      CommunityModel(
        id: 'comm-2',
        name: '🔬 Plant Pathology & Pest Advisory',
        description:
            'Expert agronomic guidance, early disease diagnosis, biological treatments, and pest outbreak warnings across regional farmlands.',
        category: 'Agronomy & Protection',
        icon: 'health_and_safety',
        creatorId: 'advisor-demo-id',
        creatorName: 'Dr. Sarah Botanical (Advisor)',
        membersCount: 58,
        isJoined: true,
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      CommunityModel(
        id: 'comm-3',
        name: '📈 Wholesale Herbal Marketplace & Pricing',
        description:
            'Direct trade network connecting certified growers with pharmaceutical laboratories, herbal tea producers, and bulk commodity buyers.',
        category: 'Marketplace & Trade',
        icon: 'trending_up',
        creatorId: 'buyer-demo-id',
        creatorName: 'Marcus Sterling (Buyer)',
        membersCount: 34,
        isJoined: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      CommunityModel(
        id: 'comm-4',
        name: '🚜 Smart Irrigation & Sustainable Tech',
        description:
            'Discussions on sensor-driven drip systems, solar pump stations, and climate-resilient farming techniques.',
        category: 'Agri-Tech & Tools',
        icon: 'agriculture',
        creatorId: 'supplier-demo-id',
        creatorName: 'Claire Dupont (Supplier)',
        membersCount: 26,
        isJoined: false,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ]);

    _mockCommunityMessages['comm-1'] = [
      ChatMessageModel(
        id: 'cm-101',
        senderId: 'farmer-demo-id',
        senderName: 'Elena Vance',
        senderRole: 'farmer',
        communityId: 'comm-1',
        content:
            'Hello everyone! Our current batch of organic Aloe Vera is showing exceptional gel density. Has anyone tried drip fertigation with bio-kelp?',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      ChatMessageModel(
        id: 'cm-102',
        senderId: 'advisor-demo-id',
        senderName: 'Dr. Sarah Botanical',
        senderRole: 'advisor',
        communityId: 'comm-1',
        content:
            'Great initiative Elena! Bio-kelp increases root cation exchange. Ensure pH is monitored around 6.5 to prevent leaf tip necrosis.',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ChatMessageModel(
        id: 'cm-103',
        senderId: 'supplier-demo-id',
        senderName: 'Claire Dupont',
        senderRole: 'supplier',
        communityId: 'comm-1',
        content:
            'We just restocked cold-pressed seaweed nutrient extract in the supplies catalog. 100% certified organic with high potassium.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];

    _mockCommunityMessages['comm-2'] = [
      ChatMessageModel(
        id: 'cm-201',
        senderId: 'advisor-demo-id',
        senderName: 'Dr. Sarah Botanical',
        senderRole: 'advisor',
        communityId: 'comm-2',
        content:
            'Seasonal Alert: Elevated humidity this week may trigger fungal leaf spots in young medicinal nurseries. Apply neem oil preventative sprays early morning.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ChatMessageModel(
        id: 'cm-202',
        senderId: 'farmer-demo-id',
        senderName: 'Elena Vance',
        senderRole: 'farmer',
        communityId: 'comm-2',
        content:
            'Thank you Dr. Sarah! We ran the plant scanner on our ginseng plots and all readings came back clear.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    _mockPrivateMessages['buyer-demo-id'] = [
      ChatMessageModel(
        id: 'pm-1',
        senderId: 'buyer-demo-id',
        senderName: 'Marcus Sterling',
        senderRole: 'customer',
        recipientId: 'current-user',
        content:
            'Hi, I saw your fresh Aloe Vera listing on the marketplace. Can we contract 500kg for delivery next month?',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ChatMessageModel(
        id: 'pm-2',
        senderId: 'current-user',
        senderName: 'You',
        senderRole: 'farmer',
        recipientId: 'buyer-demo-id',
        content:
            'Hello Marcus! Absolutely. We can prepare 500kg vacuum-packed grade A leaves. Let me send you the batch analysis certificate.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessageModel(
        id: 'pm-3',
        senderId: 'buyer-demo-id',
        senderName: 'Marcus Sterling',
        senderRole: 'customer',
        recipientId: 'current-user',
        content: 'That sounds perfect. Looking forward to the contract terms.',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ];

    _mockPrivateMessages['advisor-demo-id'] = [
      ChatMessageModel(
        id: 'pm-4',
        senderId: 'advisor-demo-id',
        senderName: 'Dr. Sarah Botanical',
        senderRole: 'advisor',
        recipientId: 'current-user',
        content:
            'Your soil sample lab report from Section 4 looks prime for Ashwagandha expansion. Nitrogen levels are optimal.',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
    ];
  }

  void resetMockStore() {
    _initializedMocks = false;
    _mockCommunities.clear();
    _mockCommunityMessages.clear();
    _mockPrivateMessages.clear();
    _initDefaultMocks();
  }

  // ── Communities ──────────────────────────────────────────────────────────

  Future<List<CommunityModel>> getCommunities({
    String? category,
    String? search,
  }) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final queryParams = <String, String>{};
        if (category != null && category.isNotEmpty && category != 'All') {
          queryParams['category'] = category;
        }
        if (search != null && search.trim().isNotEmpty) {
          queryParams['q'] = search.trim();
        }

        final uri = Uri(
          path: '/chat/communities',
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );
        final response = await ApiService.authGet(uri.toString());

        if (response['status'] == 'success' && response['data'] is List) {
          final list = (response['data'] as List)
              .map((c) => CommunityModel.fromJson(c as Map<String, dynamic>))
              .toList();
          return list;
        }
      } catch (e) {
        debugPrint('[ChatService] getCommunities API error, falling back to local mocks: $e');
      }
    }

    // Local / Offline fallback
    var filtered = List<CommunityModel>.from(_mockCommunities);
    if (category != null && category.isNotEmpty && category != 'All') {
      filtered = filtered.where((c) => c.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      filtered = filtered
          .where((c) => c.name.toLowerCase().contains(q) || c.description.toLowerCase().contains(q))
          .toList();
    }
    return filtered;
  }

  Future<CommunityModel> createCommunity({
    required String name,
    required String description,
    required String category,
    String icon = 'groups',
  }) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authPost('/chat/communities', {
          'name': name.trim(),
          'description': description.trim(),
          'category': category,
          'icon': icon,
        });

        if (response['status'] == 'success' && response['data'] is Map) {
          final newComm = CommunityModel.fromJson(response['data'] as Map<String, dynamic>);
          _mockCommunities.insert(0, newComm);
          return newComm;
        }
      } catch (e) {
        debugPrint('[ChatService] createCommunity API error, falling back to mock: $e');
      }
    }

    // Mock fallback
    final currentUser = await AuthService.getStoredUser();
    final newComm = CommunityModel(
      id: 'comm-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
      category: category,
      icon: icon,
      creatorId: currentUser?.id ?? 'current-user',
      creatorName: currentUser?.displayName ?? 'You',
      membersCount: 1,
      isJoined: true,
      createdAt: DateTime.now(),
    );
    _mockCommunities.insert(0, newComm);
    _mockCommunityMessages[newComm.id] = [];
    return newComm;
  }

  Future<bool> joinCommunity(String communityId) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authPost('/chat/communities/$communityId/join', {});
        if (response['status'] == 'success') {
          _updateMockCommunityMembership(communityId, true);
          return true;
        }
      } catch (e) {
        debugPrint('[ChatService] joinCommunity error: $e');
      }
    }

    _updateMockCommunityMembership(communityId, true);
    return true;
  }

  Future<bool> leaveCommunity(String communityId) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authPost('/chat/communities/$communityId/leave', {});
        if (response['status'] == 'success') {
          _updateMockCommunityMembership(communityId, false);
          return true;
        }
      } catch (e) {
        debugPrint('[ChatService] leaveCommunity error: $e');
      }
    }

    _updateMockCommunityMembership(communityId, false);
    return true;
  }

  void _updateMockCommunityMembership(String communityId, bool isJoined) {
    final idx = _mockCommunities.indexWhere((c) => c.id == communityId);
    if (idx != -1) {
      final old = _mockCommunities[idx];
      final newCount = isJoined ? old.membersCount + 1 : (old.membersCount > 1 ? old.membersCount - 1 : 1);
      _mockCommunities[idx] = old.copyWith(
        isJoined: isJoined,
        membersCount: newCount,
      );
    }
  }

  Future<List<ChatMessageModel>> getCommunityMessages(String communityId) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authGet('/chat/communities/$communityId/messages');
        if (response['status'] == 'success' && response['data'] is List) {
          final list = (response['data'] as List)
              .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
              .toList();
          return list;
        }
      } catch (e) {
        debugPrint('[ChatService] getCommunityMessages error: $e');
      }
    }

    return _mockCommunityMessages[communityId] ?? [];
  }

  Future<ChatMessageModel> sendCommunityMessage(String communityId, String content) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authPost('/chat/communities/$communityId/messages', {
          'content': content.trim(),
        });
        if (response['status'] == 'success' && response['data'] is Map) {
          final msg = ChatMessageModel.fromJson(response['data'] as Map<String, dynamic>);
          _mockCommunityMessages.putIfAbsent(communityId, () => []).add(msg);
          return msg;
        }
      } catch (e) {
        debugPrint('[ChatService] sendCommunityMessage error: $e');
      }
    }

    final currentUser = await AuthService.getStoredUser();
    final msg = ChatMessageModel(
      id: 'cm-${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser?.id ?? 'current-user',
      senderName: currentUser?.displayName ?? 'You',
      senderRole: currentUser?.role ?? 'farmer',
      communityId: communityId,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    _mockCommunityMessages.putIfAbsent(communityId, () => []).add(msg);
    return msg;
  }

  // ── Private Chat & Inbox ──────────────────────────────────────────────────

  Future<List<ChatConversationModel>> getInbox() async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authGet('/chat/inbox');
        if (response['status'] == 'success' && response['data'] is List) {
          final list = (response['data'] as List)
              .map((c) => ChatConversationModel.fromJson(c as Map<String, dynamic>))
              .toList();
          return list;
        }
      } catch (e) {
        debugPrint('[ChatService] getInbox error: $e');
      }
    }

    // Build conversations from mock private messages
    final list = <ChatConversationModel>[];
    _mockPrivateMessages.forEach((partnerId, messages) {
      if (messages.isNotEmpty) {
        final last = messages.last;
        final unread = messages.where((m) => m.senderId == partnerId && !m.isRead).length;
        String name = 'Agri Partner';
        String role = 'farmer';
        if (partnerId == 'buyer-demo-id') {
          name = 'Marcus Sterling';
          role = 'customer';
        } else if (partnerId == 'advisor-demo-id') {
          name = 'Dr. Sarah Botanical';
          role = 'advisor';
        } else if (partnerId == 'supplier-demo-id') {
          name = 'Claire Dupont';
          role = 'supplier';
        }

        final domain = role == 'advisor' ? '@icloud.com' : '@gmail.com';
        list.add(ChatConversationModel(
          partnerId: partnerId,
          partnerName: name,
          partnerEmail: '$role.demo$domain',
          partnerRole: role,
          lastMessage: last.content,
          lastMessageTime: last.createdAt,
          unreadCount: unread,
        ));
      }
    });

    list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return list;
  }

  Future<List<ChatMessageModel>> getPrivateMessages(String partnerId) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authGet('/chat/messages/$partnerId');
        if (response['status'] == 'success' && response['data'] is Map) {
          final data = response['data'] as Map<String, dynamic>;
          if (data['messages'] is List) {
            final list = (data['messages'] as List)
                .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
                .toList();
            return list;
          }
        }
      } catch (e) {
        debugPrint('[ChatService] getPrivateMessages error: $e');
      }
    }

    return _mockPrivateMessages[partnerId] ?? [];
  }

  Future<ChatMessageModel> sendPrivateMessage(String partnerId, String content) async {
    _initDefaultMocks();

    if (!forceMockMode) {
      try {
        final response = await ApiService.authPost('/chat/messages/$partnerId', {
          'content': content.trim(),
        });
        if (response['status'] == 'success' && response['data'] is Map) {
          final msg = ChatMessageModel.fromJson(response['data'] as Map<String, dynamic>);
          _mockPrivateMessages.putIfAbsent(partnerId, () => []).add(msg);
          return msg;
        }
      } catch (e) {
        debugPrint('[ChatService] sendPrivateMessage error: $e');
      }
    }

    final currentUser = await AuthService.getStoredUser();
    final msg = ChatMessageModel(
      id: 'pm-${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser?.id ?? 'current-user',
      senderName: currentUser?.displayName ?? 'You',
      senderRole: currentUser?.role ?? 'farmer',
      recipientId: partnerId,
      content: content.trim(),
      isRead: false,
      createdAt: DateTime.now(),
    );

    _mockPrivateMessages.putIfAbsent(partnerId, () => []).add(msg);
    return msg;
  }

  Future<void> markAsRead(String partnerId) async {
    if (!forceMockMode) {
      try {
        await ApiService.authPatch('/chat/messages/$partnerId/read', {});
      } catch (_) {}
    }

    final msgs = _mockPrivateMessages[partnerId];
    if (msgs != null) {
      for (int i = 0; i < msgs.length; i++) {
        if (msgs[i].senderId == partnerId && !msgs[i].isRead) {
          msgs[i] = ChatMessageModel(
            id: msgs[i].id,
            senderId: msgs[i].senderId,
            senderName: msgs[i].senderName,
            senderRole: msgs[i].senderRole,
            recipientId: msgs[i].recipientId,
            content: msgs[i].content,
            attachmentUrl: msgs[i].attachmentUrl,
            isRead: true,
            createdAt: msgs[i].createdAt,
          );
        }
      }
    }
  }

  Future<List<UserModel>> getAvailableUsers({String? query, String? role}) async {
    if (!forceMockMode) {
      try {
        final queryParams = <String, String>{};
        if (query != null && query.trim().isNotEmpty) {
          queryParams['q'] = query.trim();
        }
        if (role != null && role.isNotEmpty && role != 'all') {
          queryParams['role'] = role;
        }

        final uri = Uri(
          path: '/chat/users',
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );

        final response = await ApiService.authGet(uri.toString());
        if (response['status'] == 'success' && response['data'] is List) {
          final list = (response['data'] as List)
              .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
              .toList();
          return list;
        }
      } catch (e) {
        debugPrint('[ChatService] getAvailableUsers error: $e');
      }
    }

    // Default directory list of users
    final defaultUsers = [
      const UserModel(
        id: 'farmer-demo-id',
        name: 'Elena Vance',
        email: 'farmer.demo@gmail.com',
        role: 'farmer',
        phoneNumber: '+1-800-FARM-01',
      ),
      const UserModel(
        id: 'advisor-demo-id',
        name: 'Dr. Sarah Botanical',
        email: 'advisor.demo@icloud.com',
        role: 'advisor',
        phoneNumber: '+1-800-ADV-04',
      ),
      const UserModel(
        id: 'supplier-demo-id',
        name: 'Claire Dupont',
        email: 'supplier.demo@gmail.com',
        role: 'supplier',
        phoneNumber: '+1-800-SUPP-03',
      ),
      const UserModel(
        id: 'buyer-demo-id',
        name: 'Marcus Sterling',
        email: 'buyer.demo@gmail.com',
        role: 'customer',
        phoneNumber: '+1-800-BUY-02',
      ),
      const UserModel(
        id: 'investor-demo-id',
        name: 'David Greenfield',
        email: 'investor.demo@gmail.com',
        role: 'investor',
        phoneNumber: '+1-800-INV-05',
      ),
    ];

    var result = List<UserModel>.from(defaultUsers);
    if (role != null && role.isNotEmpty && role != 'all') {
      result = result.where((u) => u.role.toLowerCase() == role.toLowerCase()).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result
          .where((u) =>
              (u.name ?? '').toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }
}
