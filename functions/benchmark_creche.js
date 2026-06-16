/**
 * Benchmark to demonstrate the N+1 query inefficiency in creche reservations.
 * This simulates Firestore latency to compare sequential vs. batched approaches.
 */

const LATENCY_MS = 150; // Average Firestore query latency

// Mock Firestore Implementation
const mockDb = {
    collection: (coll) => ({
        doc: (id) => ({
            collection: (sub) => mockDb.collection(`${coll}/${id}/${sub}`),
            get: async () => {
                await new Promise(resolve => setTimeout(resolve, LATENCY_MS));
                return { exists: true, data: () => ({ capacidade_creche: 60 }) };
            }
        }),
        where: function() { return this; },
        get: async () => {
            await new Promise(resolve => setTimeout(resolve, LATENCY_MS));
            return {
                forEach: (cb) => {
                    // Simulate some existing reservations
                    for(let i=0; i<10; i++) cb({ data: () => ({ check_in: { toDate: () => new Date() }, check_out: { toDate: () => new Date() } }) });
                },
                docs: []
            };
        }
    })
};

// 1. Original N+1 Approach
async function originalApproach(dates) {
    const start = Date.now();
    for (const dateStr of dates) {
        // Simulate: await db.collection(...).where(...).get()
        await mockDb.collection("tenants").doc("test").collection("reservas_creche")
            .where("status", "in", ["reservado", "hospedado"])
            .get();

        // (Simplified inner loop processing)
    }
    return Date.now() - start;
}

// 2. Optimized Batched Approach
async function optimizedApproach(dates) {
    const start = Date.now();
    if (dates.length === 0) return 0;

    // Single query for the whole range
    await mockDb.collection("tenants").doc("test").collection("reservas_creche")
        .where("status", "in", ["reservado", "hospedado"])
        .get();

    // (Simplified in-memory processing)
    for (const dateStr of dates) {
        // Just in-memory logic here
    }

    return Date.now() - start;
}

async function runBenchmark() {
    const testCases = [1, 3, 7, 14, 30];

    console.log("⚡ Creche Reservation Performance Benchmark");
    console.log("==========================================");
    console.log(`Simulated Latency: ${LATENCY_MS}ms per query\n`);
    console.log("Dates | Sequential (ms) | Batched (ms) | Improvement");
    console.log("------|-----------------|--------------|------------");

    for (const numDates of testCases) {
        const dates = Array.from({length: numDates}, (_, i) => `2023-10-${i+1}`);

        const timeSeq = await originalApproach(dates);
        const timeBatch = await optimizedApproach(dates);

        const improvement = ((timeSeq - timeBatch) / timeSeq * 100).toFixed(1);

        console.log(`${numDates.toString().padEnd(5)} | ${timeSeq.toString().padEnd(15)} | ${timeBatch.toString().padEnd(12)} | ${improvement}%`);
    }
}

runBenchmark().catch(console.error);
