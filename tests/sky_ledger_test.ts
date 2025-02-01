import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can register new carbon credits",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const airline1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'register-credits', [
                types.ascii("FL123"),
                types.uint(100)
            ], airline1.address)
        ]);

        block.receipts[0].result.expectOk();
        assertEquals(block.receipts[0].result, types.ok(types.uint(1)));

        // Verify credit balance
        let balanceBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'get-credit-balance', [
                types.principal(airline1.address)
            ], deployer.address)
        ]);

        assertEquals(
            balanceBlock.receipts[0].result, 
            types.ok(types.uint(100))
        );
    }
});

Clarinet.test({
    name: "Only owner can verify credits",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const airline1 = accounts.get('wallet_1')!;

        // First register credits
        let block = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'register-credits', [
                types.ascii("FL123"),
                types.uint(100)
            ], airline1.address)
        ]);

        // Try to verify as non-owner (should fail)
        let verifyBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'verify-credits', [
                types.uint(1)
            ], airline1.address)
        ]);

        verifyBlock.receipts[0].result.expectErr(types.uint(100)); // err-owner-only

        // Verify as owner (should succeed)
        let ownerVerifyBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'verify-credits', [
                types.uint(1)
            ], deployer.address)
        ]);

        ownerVerifyBlock.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Can create and purchase market listings",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const airline1 = accounts.get('wallet_1')!;
        const airline2 = accounts.get('wallet_2')!;

        // Register initial credits
        let block = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'register-credits', [
                types.ascii("FL123"),
                types.uint(100)
            ], airline1.address)
        ]);

        // Create market listing
        let listingBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'create-listing', [
                types.uint(50),
                types.uint(10)
            ], airline1.address)
        ]);

        listingBlock.receipts[0].result.expectOk();

        // Purchase listing
        let purchaseBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'purchase-listing', [
                types.uint(1)
            ], airline2.address)
        ]);

        purchaseBlock.receipts[0].result.expectOk();

        // Verify balances
        let balanceBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'get-credit-balance', [
                types.principal(airline2.address)
            ], airline2.address)
        ]);

        assertEquals(
            balanceBlock.receipts[0].result,
            types.ok(types.uint(50))
        );
    }
});

Clarinet.test({
    name: "Can retire verified credits",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const airline1 = accounts.get('wallet_1')!;

        // Register and verify credits
        let block = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'register-credits', [
                types.ascii("FL123"),
                types.uint(100)
            ], airline1.address)
        ]);

        let verifyBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'verify-credits', [
                types.uint(1)
            ], deployer.address)
        ]);

        // Retire credits
        let retireBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'retire-credits', [
                types.uint(1)
            ], airline1.address)
        ]);

        retireBlock.receipts[0].result.expectOk();

        // Check total retired
        let totalRetiredBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'get-total-retired', [], deployer.address)
        ]);

        assertEquals(
            totalRetiredBlock.receipts[0].result,
            types.ok(types.uint(100))
        );
    }
});
