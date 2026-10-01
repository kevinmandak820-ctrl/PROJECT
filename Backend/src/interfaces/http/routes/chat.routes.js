const express = require('express');
const ChatController = require('../controllers/chat.controller');
const { authenticate } = require('../middlewares/auth.middleware');

const router = express.Router();

// Communities routes
router.get('/communities', authenticate, ChatController.getCommunities);
router.post('/communities', authenticate, ChatController.createCommunity);
router.get('/communities/:id', authenticate, ChatController.getCommunityDetails);
router.post('/communities/:id/join', authenticate, ChatController.joinCommunity);
router.post('/communities/:id/leave', authenticate, ChatController.leaveCommunity);
router.get('/communities/:id/messages', authenticate, ChatController.getCommunityMessages);
router.post('/communities/:id/messages', authenticate, ChatController.sendCommunityMessage);

// Private Chat & Inbox routes
router.get('/inbox', authenticate, ChatController.getInbox);
router.get('/messages/:partnerId', authenticate, ChatController.getPrivateMessages);
router.post('/messages/:partnerId', authenticate, ChatController.sendPrivateMessage);
router.patch('/messages/:partnerId/read', authenticate, ChatController.markAsRead);

// User directory for starting private conversations
router.get('/users', authenticate, ChatController.getAvailableUsers);

module.exports = router;
