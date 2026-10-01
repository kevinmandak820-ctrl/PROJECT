import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrimed_link/services/chat_service.dart';
import 'package:agrimed_link/models/community_model.dart';
import 'package:agrimed_link/models/chat_message_model.dart';
import 'package:agrimed_link/screens/chat/community_chat_hub_screen.dart';
import 'package:agrimed_link/screens/chat/community_discussion_screen.dart';
import 'package:agrimed_link/screens/chat/private_chat_screen.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    ChatService.forceMockMode = true;
    ChatService.instance.resetMockStore();
  });

  group('ChatService Unit Tests', () {
    test('Fetches default agricultural communities and categories', () async {
      final communities = await ChatService.instance.getCommunities();
      expect(communities.isNotEmpty, isTrue);
      expect(communities.any((c) => c.name.contains('Medicinal Herbs')), isTrue);
      expect(communities.any((c) => c.name.contains('Plant Pathology')), isTrue);
    });

    test('Filters communities by category', () async {
      final filtered = await ChatService.instance.getCommunities(category: 'Medicinal Crops');
      expect(filtered.every((c) => c.category == 'Medicinal Crops'), isTrue);
    });

    test('Creates new community and verifies membership', () async {
      final created = await ChatService.instance.createCommunity(
        name: 'Ginseng Growers Association',
        description: 'Collaborative group for high-elevation ginseng roots.',
        category: 'Medicinal Crops',
      );

      expect(created.name, 'Ginseng Growers Association');
      expect(created.isJoined, isTrue);

      final list = await ChatService.instance.getCommunities();
      expect(list.any((c) => c.name == 'Ginseng Growers Association'), isTrue);
    });

    test('Joins and leaves a community', () async {
      final communities = await ChatService.instance.getCommunities();
      final target = communities.firstWhere((c) => !c.isJoined, orElse: () => communities.first);

      final joined = await ChatService.instance.joinCommunity(target.id);
      expect(joined, isTrue);

      final left = await ChatService.instance.leaveCommunity(target.id);
      expect(left, isTrue);
    });

    test('Sends and receives community discussion messages', () async {
      final msg = await ChatService.instance.sendCommunityMessage(
        'comm-1',
        'Testing community discussion with bio-stimulants.',
      );
      expect(msg.content, 'Testing community discussion with bio-stimulants.');

      final messages = await ChatService.instance.getCommunityMessages('comm-1');
      expect(messages.any((m) => m.content.contains('bio-stimulants')), isTrue);
    });

    test('Manages private chat inbox and sends direct messages', () async {
      final inbox = await ChatService.instance.getInbox();
      expect(inbox.isNotEmpty, isTrue);

      final partner = inbox.first;
      final sent = await ChatService.instance.sendPrivateMessage(
        partner.partnerId,
        'Direct inquiry regarding wholesale delivery.',
      );
      expect(sent.content, 'Direct inquiry regarding wholesale delivery.');

      final history = await ChatService.instance.getPrivateMessages(partner.partnerId);
      expect(history.any((m) => m.content.contains('wholesale delivery')), isTrue);
    });
  });

  group('Chat & Community Widgets Tests', () {
    testWidgets('Renders CommunityChatHubScreen with tabs and communities list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityChatHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AgriMed Network & Chats'), findsOneWidget);
      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('Private Inbox'), findsOneWidget);

      // Verify search and category filter chips
      expect(find.text('Medicinal Crops'), findsWidgets);
      expect(find.text('Agronomy & Protection'), findsWidgets);

      // Verify create community button
      expect(find.text('Create Community'), findsOneWidget);
    });

    testWidgets('Switches to Private Inbox tab and sees conversation threads', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityChatHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Private Inbox Tab
      await tester.tap(find.text('Private Inbox'));
      await tester.pumpAndSettle();

      // Should show "New Message" button
      expect(find.text('New Message'), findsOneWidget);
      // Conversations should be rendered
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('CommunityDiscussionScreen displays messages and chatbox', (tester) async {
      final comm = CommunityModel(
        id: 'comm-1',
        name: '🌿 Medicinal Herbs & Botanicals',
        description: 'A collaborative forum for cultivating organic medicinal plants.',
        category: 'Medicinal Crops',
        creatorId: 'farmer-1',
        creatorName: 'Elena Vance',
        membersCount: 42,
        isJoined: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityDiscussionScreen(community: comm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🌿 Medicinal Herbs & Botanicals'), findsOneWidget);
      expect(find.text('Joined'), findsOneWidget);

      // Verify chatbox field and quick topics
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('🌱 Cultivation Advice'), findsOneWidget);

      // Enter a test message into chatbox
      await tester.enterText(find.byType(TextField), 'Great crop yield this season!');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Great crop yield this season!'), findsAtLeastNWidgets(1));
    });

    testWidgets('PrivateChatScreen displays 1-on-1 thread and chatbox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChatScreen(
            partnerId: 'buyer-demo-id',
            partnerName: 'Marcus Sterling',
            partnerRole: 'customer',
            partnerPhoneNumber: '+1-800-BUY-02',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marcus Sterling'), findsOneWidget);
      expect(find.text('Active now'), findsOneWidget);

      // Verify chatbox and quick inquiry chips
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('🌾 Is this crop currently available in stock?'), findsOneWidget);

      // Enter direct message into chatbox
      await tester.enterText(find.byType(TextField), 'We have 200kg ready for shipment.');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('We have 200kg ready for shipment.'), findsAtLeastNWidgets(1));
    });
  });
}

