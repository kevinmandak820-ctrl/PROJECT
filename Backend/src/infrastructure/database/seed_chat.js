const { Op } = require('sequelize');
const {
    User,
    Community,
    CommunityMember,
    CommunityMessage,
    PrivateMessage
} = require('./sequelize');

async function seedChatAndCommunities() {
    try {
        const count = await Community.count();
        if (count > 0) {
            return;
        }

        console.log('Seeding initial agricultural communities and conversations...');

        const farmer = await User.findOne({ where: { email: { [Op.in]: ['farmer.demo@gmail.com', 'farmer.demo@agrimedlink.com'] } } });
        const advisor = await User.findOne({ where: { email: { [Op.in]: ['advisor.demo@icloud.com', 'advisor.demo@agrimedlink.com'] } } });
        const supplier = await User.findOne({ where: { email: { [Op.in]: ['supplier.demo@gmail.com', 'supplier.demo@agrimedlink.com'] } } });
        const buyer = await User.findOne({ where: { email: { [Op.in]: ['buyer.demo@gmail.com', 'buyer.demo@agrimedlink.com'] } } });
        const admin = await User.findOne({ where: { email: 'system.admin@agrimedlink.com' } });

        if (!farmer || !advisor) {
            console.log('Users not ready for chat seeding yet.');
            return;
        }

        // 1. Create Communities
        const c1 = await Community.create({
            name: '🌿 Medicinal Herbs & Botanicals',
            description: 'A collaborative forum for cultivating, harvesting, and processing organic medicinal plants including Aloe Vera, Ginseng, Moringa, and Ashwagandha.',
            category: 'Medicinal Crops',
            icon: 'eco',
            creatorId: farmer.id,
            membersCount: 4
        });

        const c2 = await Community.create({
            name: '🔬 Plant Pathology & Pest Advisory',
            description: 'Expert agronomic guidance, early disease diagnosis, biological treatments, and pest outbreak warnings across regional farmlands.',
            category: 'Agronomy & Protection',
            icon: 'health_and_safety',
            creatorId: advisor.id,
            membersCount: 5
        });

        const c3 = await Community.create({
            name: '📈 Wholesale Herbal Marketplace & Pricing',
            description: 'Direct trade network connecting certified growers with pharmaceutical laboratories, herbal tea producers, and bulk commodity buyers.',
            category: 'Marketplace & Trade',
            icon: 'trending_up',
            creatorId: buyer.id,
            membersCount: 3
        });

        const c4 = await Community.create({
            name: '🚜 Smart Irrigation & Sustainable Tech',
            description: 'Discussions on sensor-driven drip systems, solar pump stations, and climate-resilient farming techniques.',
            category: 'Agri-Tech & Tools',
            icon: 'agriculture',
            creatorId: supplier.id,
            membersCount: 3
        });

        // 2. Add memberships
        const users = [farmer, advisor, supplier, buyer, admin].filter(Boolean);
        for (const u of users) {
            await CommunityMember.findOrCreate({
                where: { communityId: c1.id, userId: u.id },
                defaults: { role: u.id === farmer.id ? 'creator' : 'member' }
            });
            await CommunityMember.findOrCreate({
                where: { communityId: c2.id, userId: u.id },
                defaults: { role: u.id === advisor.id ? 'creator' : 'member' }
            });
        }
        await CommunityMember.findOrCreate({
            where: { communityId: c3.id, userId: buyer.id },
            defaults: { role: 'creator' }
        });
        await CommunityMember.findOrCreate({
            where: { communityId: c3.id, userId: farmer.id },
            defaults: { role: 'member' }
        });

        // 3. Seed Discussion Messages in Community 1
        await CommunityMessage.create({
            communityId: c1.id,
            senderId: farmer.id,
            content: 'Hello everyone! Our current batch of organic Aloe Vera is showing exceptional gel density. Has anyone tried drip fertigation with bio-kelp?'
        });

        await CommunityMessage.create({
            communityId: c1.id,
            senderId: advisor.id,
            content: 'Great initiative Elena! Bio-kelp increases root cation exchange. Ensure pH is monitored around 6.5 to prevent leaf tip necrosis.'
        });

        await CommunityMessage.create({
            communityId: c1.id,
            senderId: supplier.id,
            content: 'We just restocked cold-pressed seaweed nutrient extract in the supplies catalog. 100% certified organic.'
        });

        // Seed Discussion Messages in Community 2
        await CommunityMessage.create({
            communityId: c2.id,
            senderId: advisor.id,
            content: 'Seasonal Alert: Elevated humidity this week may trigger fungal leaf spots in young medicinal nurseries. Apply neem oil preventative sprays early morning.'
        });

        await CommunityMessage.create({
            communityId: c2.id,
            senderId: farmer.id,
            content: 'Thank you Dr. Sarah! We ran the plant scanner on our ginseng plots and all readings came back clear.'
        });

        // 4. Seed 1-on-1 Private Messages
        if (buyer && farmer) {
            await PrivateMessage.create({
                senderId: buyer.id,
                recipientId: farmer.id,
                content: 'Hi Elena, I saw your fresh Aloe Vera listing on the marketplace. Can we contract 500kg for delivery next month?',
                isRead: true
            });

            await PrivateMessage.create({
                senderId: farmer.id,
                recipientId: buyer.id,
                content: 'Hello Marcus! Absolutely. We can prepare 500kg vacuum-packed grade A leaves. Let me send you the batch analysis certificate.',
                isRead: true
            });
        }

        if (advisor && farmer) {
            await PrivateMessage.create({
                senderId: advisor.id,
                recipientId: farmer.id,
                content: 'Elena, your soil sample lab report from Section 4 looks prime for Ashwagandha expansion. Nitrogen levels are optimal.',
                isRead: false
            });
        }

        console.log('Seeded initial communities and chat messages successfully.');
    } catch (err) {
        console.error('Error seeding chat data:', err);
    }
}

module.exports = { seedChatAndCommunities };
