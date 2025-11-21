/**
 * XMTP HPKE Error Reproduction Script
 * 
 * This script reproduces the OpenMLS HPKE decryption error (AgentError 1002)
 * by creating multiple stale installations for a single wallet address.
 * 
 * Process:
 * 1. Create receiver and sender wallets
 * 2. Initialize receiver agent 3 times, deleting the DB each time to create stale installations
 * 3. Initialize receiver agent a 4th time and keep it running
 * 4. Initialize sender agent
 * 5. Send multiple messages from sender to receiver
 * 6. Monitor for HPKE decryption errors
 */

import { Agent } from '@xmtp/agent-sdk';
import { Wallet } from 'ethers';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const XMTP_ENV = (process.env.XMTP_ENV || 'dev') as 'dev' | 'production';
const DEBUG = process.env.DEBUG === 'true';
const NUM_STALE_INSTALLATIONS = 3;
const NUM_MESSAGES = 8;
const MESSAGE_DELAY_MS = 1000;

/**
 * Utility function to wait for a specified duration
 */
function delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Delete database files for a given agent
 */
function deleteAgentDatabase(dbPath: string): void {
    const extensions = ['', '-shm', '-wal'];

    for (const ext of extensions) {
        const filePath = `${dbPath}${ext}`;
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            console.log(`  🗑️  Deleted: ${path.basename(filePath)}`);
        }
    }
}

/**
 * Initialize an agent and wait for it to be ready
 */
async function initializeAgent(
    wallet: any,
    dbPath: string,
    label: string
): Promise<any> {
    console.log(`\n🚀 Initializing ${label}...`);
    console.log(`   Wallet Address: ${wallet.address}`);
    console.log(`   DB Path: ${dbPath}`);

    const agent = await Agent.create(wallet, {
        env: XMTP_ENV,
        dbPath,
    });

    // Set up error handlers
    agent.on('error', (error: Error) => {
        console.error(`\n❌ ERROR in ${label}:`, error);
        console.error('Error name:', error.name);
        console.error('Error message:', error.message);
        if ('code' in error) {
            console.error('Error code:', (error as any).code);
        }
        console.error('Stack trace:', error.stack);
    });

    // Start the agent
    await agent.start();
    console.log(`   ✅ ${label} started`);

    // Get installation ID from the client
    const installationId = agent.client.installationId;
    console.log(`   🔑 Installation ID: ${installationId}`);

    return agent;
}

/**
 * Create stale installations by repeatedly initializing and deleting the database
 */
async function createStaleInstallations(
    wallet: any,
    dbPath: string
): Promise<void> {
    console.log('\n═══════════════════════════════════════════════════════');
    console.log('PHASE 1: Creating Stale Installations');
    console.log('═══════════════════════════════════════════════════════');

    for (let i = 1; i <= NUM_STALE_INSTALLATIONS; i++) {
        console.log(`\n--- Stale Installation ${i}/${NUM_STALE_INSTALLATIONS} ---`);

        // Initialize agent
        const agent = await initializeAgent(wallet, dbPath, `Receiver (Stale #${i})`);

        // Wait a bit for the agent to be fully registered on the network
        console.log('   ⏳ Waiting for network registration...');
        await delay(3000);

        // Stop the agent
        console.log('   🛑 Stopping agent...');
        agent.stop();
        console.log('   ✅ Agent stopped');

        // Delete the database to force a new installation ID on next init
        console.log('   🗑️  Deleting database to create stale installation...');
        deleteAgentDatabase(dbPath);

        // Brief pause between iterations
        await delay(1000);
    }

    console.log('\n✅ Created ' + NUM_STALE_INSTALLATIONS + ' stale installations');
}

/**
 * Main reproduction function
 */
async function reproduce(): Promise<void> {
    console.log('╔═══════════════════════════════════════════════════════╗');
    console.log('║  XMTP HPKE Error Reproduction Script                 ║');
    console.log('╚═══════════════════════════════════════════════════════╝');
    console.log(`Environment: ${XMTP_ENV}`);
    console.log(`Debug: ${DEBUG}`);

    // Generate random wallets
    console.log('\n🔐 Generating wallets...');
    const receiverWallet = Wallet.createRandom();
    const senderWallet = Wallet.createRandom();

    console.log(`   Receiver: ${receiverWallet.address}`);
    console.log(`   Sender: ${senderWallet.address}`);

    const receiverDbPath = path.join(process.cwd(), 'receiver.db3');
    const senderDbPath = path.join(process.cwd(), 'sender.db3');

    try {
        // PHASE 1: Create stale installations
        await createStaleInstallations(receiverWallet, receiverDbPath);

        // PHASE 2: Initialize final receiver (keep it running)
        console.log('\n═══════════════════════════════════════════════════════');
        console.log('PHASE 2: Initializing Final Receiver Instance');
        console.log('═══════════════════════════════════════════════════════');

        const receiver = await initializeAgent(
            receiverWallet,
            receiverDbPath,
            'Receiver (FINAL)'
        );

        console.log('\n📡 Receiver listening for messages...');

        // Set up message listener
        receiver.on('message', (ctx: any) => {
            console.log('\n📨 Message received:');
            console.log('   From:', ctx.message.senderAddress);
            console.log('   Content:', ctx.message.content);
        });

        // PHASE 3: Initialize sender
        console.log('\n═══════════════════════════════════════════════════════');
        console.log('PHASE 3: Initializing Sender');
        console.log('═══════════════════════════════════════════════════════');

        const sender = await initializeAgent(
            senderWallet,
            senderDbPath,
            'Sender'
        );

        // Wait a bit for both agents to be fully ready
        console.log('\n⏳ Waiting for agents to sync...');
        await delay(3000);

        // PHASE 4: Send messages
        console.log('\n═══════════════════════════════════════════════════════');
        console.log('PHASE 4: Sending Messages');
        console.log('═══════════════════════════════════════════════════════');

        console.log(`\n📤 Sending ${NUM_MESSAGES} messages from Sender to Receiver...`);

        // Create a conversation from sender to receiver
        console.log('\n   Creating conversation...');
        const conversation = await sender.client.conversations.newConversation(receiverWallet.address);
        console.log(`   ✅ Conversation created: ${conversation.id}`);

        for (let i = 1; i <= NUM_MESSAGES; i++) {
            const message = `Test message ${i}/${NUM_MESSAGES} - Testing HPKE decryption with stale installations`;

            try {
                console.log(`\n   Sending message ${i}...`);
                await conversation.send(message);
                console.log(`   ✅ Message ${i} sent: "${message}"`);

                // Wait between messages
                if (i < NUM_MESSAGES) {
                    await delay(MESSAGE_DELAY_MS);
                }
            } catch (error) {
                console.error(`\n   ❌ Failed to send message ${i}:`, error);
            }
        }

        // Keep listening for a bit to catch any errors
        console.log('\n⏳ Waiting for messages to be processed...');
        await delay(10000);

        console.log('\n═══════════════════════════════════════════════════════');
        console.log('PHASE 5: Cleanup');
        console.log('═══════════════════════════════════════════════════════');

        // Clean up
        console.log('\n🛑 Stopping agents...');
        sender.stop();
        console.log('   ✅ Sender stopped');
        receiver.stop();
        console.log('   ✅ Receiver stopped');

        console.log('\n✅ Reproduction script completed');
        console.log('\n📊 Summary:');
        console.log(`   - Created ${NUM_STALE_INSTALLATIONS} stale receiver installations`);
        console.log(`   - Current receiver installation: ${receiver.client.installationId}`);
        console.log(`   - Messages sent: ${NUM_MESSAGES}`);
        console.log('\n💡 Check the logs above for any HPKE decryption errors (AgentError 1002)');

    } catch (error) {
        console.error('\n❌ FATAL ERROR:', error);
        throw error;
    }
}

// Handle unhandled errors
process.on('unhandledRejection', (reason, promise) => {
    console.error('\n❌ Unhandled Rejection at:', promise);
    console.error('Reason:', reason);
});

process.on('uncaughtException', (error) => {
    console.error('\n❌ Uncaught Exception:', error);
    process.exit(1);
});

// Run the reproduction
if (require.main === module) {
    reproduce()
        .then(() => {
            console.log('\n✅ Script finished successfully');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n❌ Script failed:', error);
            process.exit(1);
        });
}

export { reproduce };
