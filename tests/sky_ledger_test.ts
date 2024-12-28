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
    name: "Can transfer credits between accounts",
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

        // Transfer credits
        let transferBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'transfer-credits', [
                types.uint(50),
                types.principal(airline2.address)
            ], airline1.address)
        ]);

        transferBlock.receipts[0].result.expectOk();

        // Verify balances
        let balanceBlock = chain.mineBlock([
            Tx.contractCall('sky_ledger', 'get-credit-balance', [
                types.principal(airline1.address)
            ], airline1.address),
            Tx.contractCall('sky_ledger', 'get-credit-balance', [
                types.principal(airline2.address)
            ], airline2.address)
        ]);

        assertEquals(
            balanceBlock.receipts[0].result,
            types.ok(types.uint(50))
        );
        assertEquals(
            balanceBlock.receipts[1].result,
            types.ok(types.uint(50))
        );
    }
});