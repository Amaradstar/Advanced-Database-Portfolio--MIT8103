// Portfolio 4: compare query plans before and after indexes.

const cedar = db.getSiblingDB('CedarPay_db');

function stageNames(explain) {
    const names = [];

    function walk(node) {
        if (!node) return;
        if (node.stage) names.push(node.stage);
        if (node.inputStage) walk(node.inputStage);
        if (node.inputStages) node.inputStages.forEach(walk);
        if (node.queryPlan) walk(node.queryPlan);
    }

    walk(explain.queryPlanner.winningPlan);
    return names;
}

function report(label, cursor) {
    const explain = cursor.explain('executionStats');
    const stats = explain.executionStats;

    print('  [' + label + ']');
    print('    plan stages         : ' + stageNames(explain).join(' > '));
    print('    documents examined  : ' + stats.totalDocsExamined);
    print('    index keys examined : ' + stats.totalKeysExamined);
    print('    documents returned  : ' + stats.nReturned);
    print('    execution time (ms) : ' + stats.executionTimeMillis);
}

// Remove non-_id indexes so the "before" measurements are meaningful.
cedar.audit_events.dropIndexes();
cedar.kyc_profiles.dropIndexes();

const q1 = function () {
    return cedar.audit_events
        .find({ customer_id: 1001 })
        .sort({ ts: -1 })
        .limit(20);
};

const q2 = function () {
    return cedar.audit_events.find({
        event_type: 'FRAUD_FLAG',
        ts: { $gte: new Date(Date.now() - 7 * 86400000) }
    });
};

const q3 = function () {
    return cedar.kyc_profiles.find({ customer_id: 2500 });
};

print('############ BEFORE indexes ############');
print('Q1: latest 20 events for customer 1001');
report('before', q1());

print('Q2: FRAUD_FLAG events in the last 7 days');
report('before', q2());

print('Q3: KYC profile for customer 2500');
report('before', q3());

// Create indexes for the three measured queries.
print('\n############ Creating indexes ############');

print(cedar.audit_events.createIndex(
    { customer_id: 1, ts: -1 },
    { name: 'idx_audit_customer_ts' }
));

print(cedar.audit_events.createIndex(
    { event_type: 1, ts: -1 },
    { name: 'idx_audit_type_ts' }
));

print(cedar.kyc_profiles.createIndex(
    { customer_id: 1 },
    { unique: true, name: 'uq_kyc_customer' }
));

print('\n############ AFTER indexes ############');
print('Q1: latest 20 events for customer 1001');
report('after', q1());

print('Q2: FRAUD_FLAG events in the last 7 days');
report('after', q2());

print('Q3: KYC profile for customer 2500');
report('after', q3());

// Customer 2 already has a profile in CedarPay's 2..5001 ID range.
// A second profile for that customer should fail the unique index.
print('\n############ Unique index in action ############');

try {
    const inserted = cedar.kyc_profiles.insertOne({
        customer_id: 2,
        tier: 1,
        status: 'PENDING',
        documents: [{ type: 'BVN', number: '11111111111' }],
        created_at: new Date()
    });

    cedar.kyc_profiles.deleteOne({ _id: inserted.insertedId });
    print('FAIL: duplicate customer_id accepted; temporary test record removed');
} catch (error) {
    const errorName =
        error.code === 11000 ? 'DuplicateKey' : error.codeName;

    print(
        'PASS: duplicate customer_id rejected -> ' +
        errorName +
        ' (code ' +
        error.code +
        ')'
    );
}

// Demonstrate a one-hour TTL index on login sessions.
// This clears only the portfolio's demo session collection.
print('\n############ TTL index on login_sessions ############');

cedar.login_sessions.deleteMany({});

cedar.login_sessions.createIndex(
    { created_at: 1 },
    { expireAfterSeconds: 3600, name: 'ttl_session_1h' }
);

cedar.login_sessions.insertMany([
    {
        customer_id: 1001,
        token: 'tok-recent',
        created_at: new Date()
    },
    {
        customer_id: 1002,
        token: 'tok-old',
        created_at: new Date(Date.now() - 2 * 3600 * 1000)
    }
]);

print('Inserted 2 sessions: one recent and one older than one hour.');
print('The old session should disappear after the TTL monitor processes it.');

// Report data and index sizes when the server makes those stats available.
print('\n############ Index sizes ############');

['audit_events', 'kyc_profiles'].forEach(function (collectionName) {
    try {
        const stats = cedar.getCollection(collectionName).stats();
        print(
            collectionName +
            ': data=' +
            (stats.size / 1048576).toFixed(1) +
            ' MB, indexes=' +
            (stats.totalIndexSize / 1048576).toFixed(1) +
            ' MB'
        );
    } catch (error) {
        print(
            collectionName +
            ': stats not available here; check Compass collection statistics.'
        );
    }
});