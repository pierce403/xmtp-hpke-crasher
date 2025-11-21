"use strict";
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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.reproduce = reproduce;
var agent_sdk_1 = require("@xmtp/agent-sdk");
var ethers_1 = require("ethers");
var dotenv_1 = require("dotenv");
var fs_1 = require("fs");
var path_1 = require("path");
dotenv_1.default.config();
var XMTP_ENV = (process.env.XMTP_ENV || 'dev');
var DEBUG = process.env.DEBUG === 'true';
var NUM_STALE_INSTALLATIONS = 3;
var NUM_MESSAGES = 8;
var MESSAGE_DELAY_MS = 1000;
/**
 * Utility function to wait for a specified duration
 */
function delay(ms) {
    return new Promise(function (resolve) { return setTimeout(resolve, ms); });
}
/**
 * Delete database files for a given agent
 */
function deleteAgentDatabase(dbPath) {
    var extensions = ['', '-shm', '-wal'];
    for (var _i = 0, extensions_1 = extensions; _i < extensions_1.length; _i++) {
        var ext = extensions_1[_i];
        var filePath = "".concat(dbPath).concat(ext);
        if (fs_1.default.existsSync(filePath)) {
            fs_1.default.unlinkSync(filePath);
            console.log("  \uD83D\uDDD1\uFE0F  Deleted: ".concat(path_1.default.basename(filePath)));
        }
    }
}
/**
 * Initialize an agent and wait for it to be ready
 */
function initializeAgent(wallet, dbPath, label) {
    return __awaiter(this, void 0, void 0, function () {
        var agent, installationId;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    console.log("\n\uD83D\uDE80 Initializing ".concat(label, "..."));
                    console.log("   Wallet Address: ".concat(wallet.address));
                    console.log("   DB Path: ".concat(dbPath));
                    agent = new agent_sdk_1.Agent(wallet, {
                        env: XMTP_ENV,
                        dbPath: dbPath,
                    });
                    // Set up error handlers
                    agent.on('error', function (error) {
                        console.error("\n\u274C ERROR in ".concat(label, ":"), error);
                        console.error('Error name:', error.name);
                        console.error('Error message:', error.message);
                        if ('code' in error) {
                            console.error('Error code:', error.code);
                        }
                        console.error('Stack trace:', error.stack);
                    });
                    // Start the agent
                    return [4 /*yield*/, agent.start()];
                case 1:
                    // Start the agent
                    _a.sent();
                    console.log("   \u2705 ".concat(label, " started"));
                    installationId = agent.installationId;
                    console.log("   \uD83D\uDD11 Installation ID: ".concat(installationId));
                    return [2 /*return*/, agent];
            }
        });
    });
}
/**
 * Create stale installations by repeatedly initializing and deleting the database
 */
function createStaleInstallations(wallet, dbPath) {
    return __awaiter(this, void 0, void 0, function () {
        var i, agent;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    console.log('\n═══════════════════════════════════════════════════════');
                    console.log('PHASE 1: Creating Stale Installations');
                    console.log('═══════════════════════════════════════════════════════');
                    i = 1;
                    _a.label = 1;
                case 1:
                    if (!(i <= NUM_STALE_INSTALLATIONS)) return [3 /*break*/, 7];
                    console.log("\n--- Stale Installation ".concat(i, "/").concat(NUM_STALE_INSTALLATIONS, " ---"));
                    return [4 /*yield*/, initializeAgent(wallet, dbPath, "Receiver (Stale #".concat(i, ")"))];
                case 2:
                    agent = _a.sent();
                    // Wait a bit for the agent to be fully registered on the network
                    console.log('   ⏳ Waiting for network registration...');
                    return [4 /*yield*/, delay(3000)];
                case 3:
                    _a.sent();
                    // Stop the agent
                    console.log('   🛑 Stopping agent...');
                    return [4 /*yield*/, agent.stop()];
                case 4:
                    _a.sent();
                    console.log('   ✅ Agent stopped');
                    // Delete the database to force a new installation ID on next init
                    console.log('   🗑️  Deleting database to create stale installation...');
                    deleteAgentDatabase(dbPath);
                    // Brief pause between iterations
                    return [4 /*yield*/, delay(1000)];
                case 5:
                    // Brief pause between iterations
                    _a.sent();
                    _a.label = 6;
                case 6:
                    i++;
                    return [3 /*break*/, 1];
                case 7:
                    console.log('\n✅ Created ' + NUM_STALE_INSTALLATIONS + ' stale installations');
                    return [2 /*return*/];
            }
        });
    });
}
/**
 * Main reproduction function
 */
function reproduce() {
    return __awaiter(this, void 0, void 0, function () {
        var receiverWallet, senderWallet, receiverDbPath, senderDbPath, receiver, sender, i, message, error_1, error_2;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    console.log('╔═══════════════════════════════════════════════════════╗');
                    console.log('║  XMTP HPKE Error Reproduction Script                 ║');
                    console.log('╚═══════════════════════════════════════════════════════╝');
                    console.log("Environment: ".concat(XMTP_ENV));
                    console.log("Debug: ".concat(DEBUG));
                    // Generate random wallets
                    console.log('\n🔐 Generating wallets...');
                    receiverWallet = ethers_1.Wallet.createRandom();
                    senderWallet = ethers_1.Wallet.createRandom();
                    console.log("   Receiver: ".concat(receiverWallet.address));
                    console.log("   Sender: ".concat(senderWallet.address));
                    receiverDbPath = path_1.default.join(process.cwd(), 'receiver.db3');
                    senderDbPath = path_1.default.join(process.cwd(), 'sender.db3');
                    _a.label = 1;
                case 1:
                    _a.trys.push([1, 17, , 18]);
                    // PHASE 1: Create stale installations
                    return [4 /*yield*/, createStaleInstallations(receiverWallet, receiverDbPath)];
                case 2:
                    // PHASE 1: Create stale installations
                    _a.sent();
                    // PHASE 2: Initialize final receiver (keep it running)
                    console.log('\n═══════════════════════════════════════════════════════');
                    console.log('PHASE 2: Initializing Final Receiver Instance');
                    console.log('═══════════════════════════════════════════════════════');
                    return [4 /*yield*/, initializeAgent(receiverWallet, receiverDbPath, 'Receiver (FINAL)')];
                case 3:
                    receiver = _a.sent();
                    console.log('\n📡 Receiver listening for messages...');
                    // Set up message listener
                    receiver.on('message', function (message) {
                        console.log('\n📨 Message received:');
                        console.log('   From:', message.senderAddress);
                        console.log('   Content:', message.content);
                    });
                    // PHASE 3: Initialize sender
                    console.log('\n═══════════════════════════════════════════════════════');
                    console.log('PHASE 3: Initializing Sender');
                    console.log('═══════════════════════════════════════════════════════');
                    return [4 /*yield*/, initializeAgent(senderWallet, senderDbPath, 'Sender')];
                case 4:
                    sender = _a.sent();
                    // Wait a bit for both agents to be fully ready
                    console.log('\n⏳ Waiting for agents to sync...');
                    return [4 /*yield*/, delay(3000)];
                case 5:
                    _a.sent();
                    // PHASE 4: Send messages
                    console.log('\n═══════════════════════════════════════════════════════');
                    console.log('PHASE 4: Sending Messages');
                    console.log('═══════════════════════════════════════════════════════');
                    console.log("\n\uD83D\uDCE4 Sending ".concat(NUM_MESSAGES, " messages from Sender to Receiver..."));
                    i = 1;
                    _a.label = 6;
                case 6:
                    if (!(i <= NUM_MESSAGES)) return [3 /*break*/, 13];
                    message = "Test message ".concat(i, "/").concat(NUM_MESSAGES, " - Testing HPKE decryption with stale installations");
                    _a.label = 7;
                case 7:
                    _a.trys.push([7, 11, , 12]);
                    console.log("\n   Sending message ".concat(i, "..."));
                    return [4 /*yield*/, sender.send(receiverWallet.address, message)];
                case 8:
                    _a.sent();
                    console.log("   \u2705 Message ".concat(i, " sent: \"").concat(message, "\""));
                    if (!(i < NUM_MESSAGES)) return [3 /*break*/, 10];
                    return [4 /*yield*/, delay(MESSAGE_DELAY_MS)];
                case 9:
                    _a.sent();
                    _a.label = 10;
                case 10: return [3 /*break*/, 12];
                case 11:
                    error_1 = _a.sent();
                    console.error("\n   \u274C Failed to send message ".concat(i, ":"), error_1);
                    return [3 /*break*/, 12];
                case 12:
                    i++;
                    return [3 /*break*/, 6];
                case 13:
                    // Keep listening for a bit to catch any errors
                    console.log('\n⏳ Waiting for messages to be processed...');
                    return [4 /*yield*/, delay(10000)];
                case 14:
                    _a.sent();
                    console.log('\n═══════════════════════════════════════════════════════');
                    console.log('PHASE 5: Cleanup');
                    console.log('═══════════════════════════════════════════════════════');
                    // Clean up
                    console.log('\n🛑 Stopping agents...');
                    return [4 /*yield*/, sender.stop()];
                case 15:
                    _a.sent();
                    console.log('   ✅ Sender stopped');
                    return [4 /*yield*/, receiver.stop()];
                case 16:
                    _a.sent();
                    console.log('   ✅ Receiver stopped');
                    console.log('\n✅ Reproduction script completed');
                    console.log('\n📊 Summary:');
                    console.log("   - Created ".concat(NUM_STALE_INSTALLATIONS, " stale receiver installations"));
                    console.log("   - Current receiver installation: ".concat(receiver.installationId));
                    console.log("   - Messages sent: ".concat(NUM_MESSAGES));
                    console.log('\n💡 Check the logs above for any HPKE decryption errors (AgentError 1002)');
                    return [3 /*break*/, 18];
                case 17:
                    error_2 = _a.sent();
                    console.error('\n❌ FATAL ERROR:', error_2);
                    throw error_2;
                case 18: return [2 /*return*/];
            }
        });
    });
}
// Handle unhandled errors
process.on('unhandledRejection', function (reason, promise) {
    console.error('\n❌ Unhandled Rejection at:', promise);
    console.error('Reason:', reason);
});
process.on('uncaughtException', function (error) {
    console.error('\n❌ Uncaught Exception:', error);
    process.exit(1);
});
// Run the reproduction
if (require.main === module) {
    reproduce()
        .then(function () {
        console.log('\n✅ Script finished successfully');
        process.exit(0);
    })
        .catch(function (error) {
        console.error('\n❌ Script failed:', error);
        process.exit(1);
    });
}
