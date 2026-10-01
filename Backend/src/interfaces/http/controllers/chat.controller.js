const { Op } = require('sequelize');
const {
    Community,
    CommunityMember,
    CommunityMessage,
    PrivateMessage,
    User
} = require('../../../infrastructure/database/sequelize');

class ChatController {
    /**
     * Get all communities with optional filtering and joined state
     */
    static async getCommunities(req, res, next) {
        try {
            const { category, q } = req.query;
            const currentUserId = req.user ? req.user.id : null;

            const whereClause = {};
            if (category && category !== 'All') {
                whereClause.category = category;
            }
            if (q && q.trim().length > 0) {
                whereClause[Op.or] = [
                    { name: { [Op.like]: `%${q.trim()}%` } },
                    { description: { [Op.like]: `%${q.trim()}%` } }
                ];
            }

            const communities = await Community.findAll({
                where: whereClause,
                order: [['createdAt', 'DESC']],
                include: [
                    {
                        model: User,
                        as: 'creator',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            // Check joined status for current user if authenticated
            let userJoinedIds = new Set();
            if (currentUserId) {
                const userMemberships = await CommunityMember.findAll({
                    where: { userId: currentUserId },
                    attributes: ['communityId']
                });
                userJoinedIds = new Set(userMemberships.map(m => m.communityId));
            }

            const formatted = communities.map(c => {
                const json = c.toJSON();
                json.isJoined = userJoinedIds.has(c.id);
                return json;
            });

            return res.status(200).json({
                status: 'success',
                data: formatted
            });
        } catch (error) {
            console.error('Error fetching communities:', error);
            next(error);
        }
    }

    /**
     * Create a new community
     */
    static async createCommunity(req, res, next) {
        try {
            const { name, description, category, icon } = req.body;
            const creatorId = req.user.id;

            if (!name || name.trim().length === 0) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Community name is required'
                });
            }

            const community = await Community.create({
                name: name.trim(),
                description: description ? description.trim() : '',
                category: category || 'General',
                icon: icon || 'groups',
                creatorId,
                membersCount: 1
            });

            // Add creator as member
            await CommunityMember.create({
                communityId: community.id,
                userId: creatorId,
                role: 'creator'
            });

            const fresh = await Community.findByPk(community.id, {
                include: [
                    {
                        model: User,
                        as: 'creator',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            const responseData = fresh.toJSON();
            responseData.isJoined = true;

            return res.status(201).json({
                status: 'success',
                message: 'Community created successfully',
                data: responseData
            });
        } catch (error) {
            console.error('Error creating community:', error);
            next(error);
        }
    }

    /**
     * Get community details
     */
    static async getCommunityDetails(req, res, next) {
        try {
            const { id } = req.params;
            const currentUserId = req.user ? req.user.id : null;

            const community = await Community.findByPk(id, {
                include: [
                    {
                        model: User,
                        as: 'creator',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            if (!community) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Community not found'
                });
            }

            let isJoined = false;
            if (currentUserId) {
                const membership = await CommunityMember.findOne({
                    where: { communityId: id, userId: currentUserId }
                });
                isJoined = !!membership;
            }

            const data = community.toJSON();
            data.isJoined = isJoined;

            return res.status(200).json({
                status: 'success',
                data
            });
        } catch (error) {
            console.error('Error fetching community details:', error);
            next(error);
        }
    }

    /**
     * Join a community
     */
    static async joinCommunity(req, res, next) {
        try {
            const { id } = req.params;
            const userId = req.user.id;

            const community = await Community.findByPk(id);
            if (!community) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Community not found'
                });
            }

            const existing = await CommunityMember.findOne({
                where: { communityId: id, userId }
            });

            if (!existing) {
                await CommunityMember.create({
                    communityId: id,
                    userId,
                    role: 'member'
                });
                community.membersCount += 1;
                await community.save();
            }

            return res.status(200).json({
                status: 'success',
                message: 'Joined community successfully',
                data: {
                    communityId: id,
                    membersCount: community.membersCount,
                    isJoined: true
                }
            });
        } catch (error) {
            console.error('Error joining community:', error);
            next(error);
        }
    }

    /**
     * Leave a community
     */
    static async leaveCommunity(req, res, next) {
        try {
            const { id } = req.params;
            const userId = req.user.id;

            const community = await Community.findByPk(id);
            if (!community) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Community not found'
                });
            }

            const existing = await CommunityMember.findOne({
                where: { communityId: id, userId }
            });

            if (existing) {
                await existing.destroy();
                community.membersCount = Math.max(1, community.membersCount - 1);
                await community.save();
            }

            return res.status(200).json({
                status: 'success',
                message: 'Left community successfully',
                data: {
                    communityId: id,
                    membersCount: community.membersCount,
                    isJoined: false
                }
            });
        } catch (error) {
            console.error('Error leaving community:', error);
            next(error);
        }
    }

    /**
     * Get discussion messages in a community
     */
    static async getCommunityMessages(req, res, next) {
        try {
            const { id } = req.params;

            const messages = await CommunityMessage.findAll({
                where: { communityId: id },
                order: [['createdAt', 'ASC']],
                include: [
                    {
                        model: User,
                        as: 'sender',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            return res.status(200).json({
                status: 'success',
                data: messages
            });
        } catch (error) {
            console.error('Error fetching community messages:', error);
            next(error);
        }
    }

    /**
     * Send a discussion message to a community
     */
    static async sendCommunityMessage(req, res, next) {
        try {
            const { id } = req.params;
            const { content, attachmentUrl } = req.body;
            const senderId = req.user.id;

            if (!content || content.trim().length === 0) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Message content cannot be empty'
                });
            }

            const community = await Community.findByPk(id);
            if (!community) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Community not found'
                });
            }

            const message = await CommunityMessage.create({
                communityId: id,
                senderId,
                content: content.trim(),
                attachmentUrl: attachmentUrl || null
            });

            // Ensure sender is a member
            const isMember = await CommunityMember.findOne({
                where: { communityId: id, userId: senderId }
            });
            if (!isMember) {
                await CommunityMember.create({
                    communityId: id,
                    userId: senderId,
                    role: 'member'
                });
                community.membersCount += 1;
                await community.save();
            }

            const fullMessage = await CommunityMessage.findByPk(message.id, {
                include: [
                    {
                        model: User,
                        as: 'sender',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            return res.status(201).json({
                status: 'success',
                message: 'Message posted successfully',
                data: fullMessage
            });
        } catch (error) {
            console.error('Error posting community message:', error);
            next(error);
        }
    }

    /**
     * Get private chat inbox (list of conversations with last message & unread count)
     */
    static async getInbox(req, res, next) {
        try {
            const userId = req.user.id;

            // Find all private messages involving current user
            const messages = await PrivateMessage.findAll({
                where: {
                    [Op.or]: [
                        { senderId: userId },
                        { recipientId: userId }
                    ]
                },
                order: [['createdAt', 'DESC']],
                include: [
                    {
                        model: User,
                        as: 'sender',
                        attributes: ['id', 'name', 'email', 'role']
                    },
                    {
                        model: User,
                        as: 'recipient',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            // Group by the other conversation partner
            const conversationsMap = new Map();

            for (const msg of messages) {
                const isSentByMe = msg.senderId === userId;
                const partner = isSentByMe ? msg.recipient : msg.sender;

                if (!partner) continue;

                if (!conversationsMap.has(partner.id)) {
                    conversationsMap.set(partner.id, {
                        partnerId: partner.id,
                        partnerName: partner.name || partner.email.split('@')[0],
                        partnerEmail: partner.email,
                        partnerRole: partner.role,
                        lastMessage: msg.content,
                        lastMessageTime: msg.createdAt,
                        unreadCount: 0
                    });
                }

                // If message was sent to me and unread, increment count
                if (!isSentByMe && !msg.isRead) {
                    const conv = conversationsMap.get(partner.id);
                    conv.unreadCount += 1;
                }
            }

            const conversations = Array.from(conversationsMap.values());

            return res.status(200).json({
                status: 'success',
                data: conversations
            });
        } catch (error) {
            console.error('Error fetching inbox:', error);
            next(error);
        }
    }

    /**
     * Get direct 1-on-1 message history with another user
     */
    static async getPrivateMessages(req, res, next) {
        try {
            const userId = req.user.id;
            const { partnerId } = req.params;

            const partner = await User.findByPk(partnerId, {
                attributes: ['id', 'name', 'email', 'role', 'phone_number']
            });

            if (!partner) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Recipient user not found'
                });
            }

            const messages = await PrivateMessage.findAll({
                where: {
                    [Op.or]: [
                        { senderId: userId, recipientId: partnerId },
                        { senderId: partnerId, recipientId: userId }
                    ]
                },
                order: [['createdAt', 'ASC']],
                include: [
                    {
                        model: User,
                        as: 'sender',
                        attributes: ['id', 'name', 'email', 'role']
                    },
                    {
                        model: User,
                        as: 'recipient',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            // Mark received unread messages as read
            await PrivateMessage.update(
                { isRead: true },
                {
                    where: {
                        senderId: partnerId,
                        recipientId: userId,
                        isRead: false
                    }
                }
            );

            return res.status(200).json({
                status: 'success',
                data: {
                    partner: {
                        id: partner.id,
                        name: partner.name || partner.email.split('@')[0],
                        email: partner.email,
                        role: partner.role,
                        phoneNumber: partner.phone_number
                    },
                    messages
                }
            });
        } catch (error) {
            console.error('Error fetching private messages:', error);
            next(error);
        }
    }

    /**
     * Send a direct 1-on-1 message to another user
     */
    static async sendPrivateMessage(req, res, next) {
        try {
            const senderId = req.user.id;
            const { partnerId } = req.params;
            const { content, attachmentUrl } = req.body;

            if (!content || content.trim().length === 0) {
                return res.status(400).json({
                    status: 'error',
                    message: 'Message content cannot be empty'
                });
            }

            const recipient = await User.findByPk(partnerId);
            if (!recipient) {
                return res.status(404).json({
                    status: 'error',
                    message: 'Recipient user not found'
                });
            }

            const message = await PrivateMessage.create({
                senderId,
                recipientId: partnerId,
                content: content.trim(),
                attachmentUrl: attachmentUrl || null,
                isRead: false
            });

            const fullMessage = await PrivateMessage.findByPk(message.id, {
                include: [
                    {
                        model: User,
                        as: 'sender',
                        attributes: ['id', 'name', 'email', 'role']
                    },
                    {
                        model: User,
                        as: 'recipient',
                        attributes: ['id', 'name', 'email', 'role']
                    }
                ]
            });

            return res.status(201).json({
                status: 'success',
                message: 'Message sent successfully',
                data: fullMessage
            });
        } catch (error) {
            console.error('Error sending private message:', error);
            next(error);
        }
    }

    /**
     * Mark private messages from partner as read
     */
    static async markAsRead(req, res, next) {
        try {
            const userId = req.user.id;
            const { partnerId } = req.params;

            await PrivateMessage.update(
                { isRead: true },
                {
                    where: {
                        senderId: partnerId,
                        recipientId: userId,
                        isRead: false
                    }
                }
            );

            return res.status(200).json({
                status: 'success',
                message: 'Messages marked as read'
            });
        } catch (error) {
            console.error('Error marking messages as read:', error);
            next(error);
        }
    }

    /**
     * Get directory of users available for chat
     */
    static async getAvailableUsers(req, res, next) {
        try {
            const currentUserId = req.user.id;
            const { q, role } = req.query;

            const whereClause = {
                id: { [Op.ne]: currentUserId },
                status: 'active'
            };

            if (role && role !== 'all') {
                whereClause.role = role.toLowerCase();
            }

            if (q && q.trim().length > 0) {
                whereClause[Op.or] = [
                    { name: { [Op.like]: `%${q.trim()}%` } },
                    { email: { [Op.like]: `%${q.trim()}%` } }
                ];
            }

            const users = await User.findAll({
                where: whereClause,
                attributes: ['id', 'name', 'email', 'role', 'phone_number'],
                order: [['name', 'ASC']]
            });

            return res.status(200).json({
                status: 'success',
                data: users
            });
        } catch (error) {
            console.error('Error fetching available users:', error);
            next(error);
        }
    }
}

module.exports = ChatController;
