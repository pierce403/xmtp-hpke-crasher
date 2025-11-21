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
 * Create an XMTP-compatible signer from an ethers Wallet
 */
function createSignerFromWallet(wallet: Wallet): any {
    return {
        type: 'EOA',
        getIdentifier: () => ({
            identifier: wallet.address.toLowerCase(),
            identifierKind: 0,  // IdentifierKind.Ethereum = 0
        }),
        signMessage: async (message: string): Promise<Uint8Array> => {
            const signature = await wallet.signMessage(message);
            // Remove '0x' prefix and convert hex string to Uint8Array
            const hexStr = signature.startsWith('0x') ? signature.slice(2) : signature;
            return new Uint8Array(Buffer.from(hexStr, 'hex'));
        },
    };
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

    // Create XMTP-compatible signer
    const signer = createSignerFromWallet(wallet);

    const agent = await Agent.create(signer, {
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
    console.log(`   ... calling agent.start() for ${label}`);
    await agent.start();
    console.log(`   ✅ ${label} started`);

    // Get installation ID from the client
    const installationId = agent.client.installationId;
    console.log(`   🔑 Installation ID: ${installationId}`);

    return agent;
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

    // Clean up any existing DBs from previous runs
    console.log('   🧹 Cleaning up old databases...');
    deleteAgentDatabase(receiverDbPath);
    deleteAgentDatabase(senderDbPath);

    try {
        // PHASE 1: Initialize Receiver
        console.log('\n═══════════════════════════════════════════════════════');
        console.log('PHASE 1: Receiver Initialization');
        console.log('═══════════════════════════════════════════════════════');

        const receiverAgent = await initializeAgent(receiverWallet, receiverDbPath, 'Receiver');

        // Listen for messages on the receiver
        console.log('   👂 Receiver listening for messages...');

        // Create a promise that resolves when the poke message is received
        const pokeReceived = new Promise<void>((resolve) => {
            receiverAgent.on('message', async (message: any) => {
                try {
                    const text = message.content.text || message.content;
                    console.log(`   📩 Receiver got message: "${text}"`);

                    if (text === 'poke') {
                        console.log('\n✅ SUCCESS: Received "poke" message! Test passed.');
                        resolve();
                    }
                } catch (err) {
                    console.error('   ❌ Error processing message:', err);
                }
            });
        });

        // PHASE 2: Initialize Sender and send message
        console.log('\n═══════════════════════════════════════════════════════');
        console.log('PHASE 2: Sender Initialization & Messaging');
        console.log('═══════════════════════════════════════════════════════');

        const senderAgent = await initializeAgent(senderWallet, senderDbPath, 'Sender');

        // Create conversation
        console.log(`   🤝 Creating conversation with ${receiverWallet.address}...`);
        const conversation = await senderAgent.conversations.newConversation(receiverWallet.address);

        console.log('   📤 Sending "poke" message...');
        await conversation.send('poke');
        console.log('   ✅ "poke" message sent');

        // Wait for the poke to be received or timeout
        console.log('   ⏳ Waiting for receiver to get the message...');

        await Promise.race([
            pokeReceived,
            delay(30000).then(() => {
                throw new Error('Timeout waiting for poke message');
            })
        ]);

        console.log('\n═══════════════════════════════════════════════════════');
        console.log('EXECUTION COMPLETE');
        console.log('═══════════════════════════════════════════════════════');

        // Cleanup
        console.log('\n🛑 Stopping agents...');
        await senderAgent.stop();
        await receiverAgent.stop();

        process.exit(0);

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

module.exports = { reproduce };
