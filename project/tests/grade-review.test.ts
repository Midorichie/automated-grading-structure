import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure that grade review requests can be submitted",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const student = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('grade-review', 'request-grade-review', [
                types.uint(1),              // assignment_id
                types.uint(85),             // original_grade
                types.ascii("Grade calculation error") // reason
            ], student.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result, '(ok u1)');
    }
});

Clarinet.test({
    name: "Ensure that only contract owner can respond to reviews",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const student = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('grade-review', 'respond-to-review', [
                types.uint(1),              // review_id
                types.uint(2),              // status (APPROVED)
                types.ascii("Grade updated"), // feedback
                types.some(types.uint(90))  // new_grade
            ], student.address)
        ]);
        
        assertEquals(block.receipts[0].result, '(err u200)'); // ERR-NOT-AUTHORIZED
    }
});

Clarinet.test({
    name: "Test invalid input validation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const student = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('grade-review', 'request-grade-review', [
                types.uint(1000001),        // invalid assignment_id
                types.uint(85),             
                types.ascii("Test")
            ], student.address)
        ]);
        
        assertEquals(block.receipts[0].result, '(err u205)'); // ERR-INVALID-ASSIGNMENT-ID
    }
});
