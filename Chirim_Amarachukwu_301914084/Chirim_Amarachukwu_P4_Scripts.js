// Portfolio 4: CedarPay MongoDB schema validation.
// Run from Compass's embedded MongoDB shell with load().
//
// MongoDB is schema-flexible, not schema-less: these validators require
// core fields while allowing optional data to vary between documents.

const nosql = db.getSiblingDB('CedarPay_db');
const portfolioCollections = [
    'kyc_profiles',
    'audit_events',
    'login_sessions'
];

// Recreate only the three Portfolio 4 collections.
portfolioCollections.forEach(function (name) {
    nosql.getCollection(name).drop();
});

// One KYC profile per customer. Identity documents are embedded because
// they are read with the profile and their fields vary by document type.
nosql.createCollection('kyc_profiles', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'tier', 'status', 'documents', 'created_at'],
            properties: {
                customer_id: {
                    bsonType: 'number',
                    minimum: 1,
                    description: 'Matches customers.customer_id in PostgreSQL'
                },
                tier: {
                    bsonType: 'number',
                    minimum: 1,
                    maximum: 3
                },
                status: {
                    enum: ['PENDING', 'VERIFIED', 'REJECTED']
                },
                documents: {
                    bsonType: 'array',
                    minItems: 1,
                    items: {
                        bsonType: 'object',
                        required: ['type', 'number'],
                        properties: {
                            type: {
                                enum: ['BVN', 'NIN', 'PASSPORT', 'DRIVERS_LICENCE', 'UTILITY_BILL']
                            },
                            number: {
                                bsonType: 'string'
                            }
                        }
                    }
                },
                created_at: {
                    bsonType: 'date'
                }
            }
        }
    },
    validationAction: 'error'
});

// Audit events are separate because they grow over time and have
// event-specific details.
nosql.createCollection('audit_events', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'event_type', 'ts', 'details'],
            properties: {
                customer_id: {
                    bsonType: 'number',
                    minimum: 1
                },
                event_type: {
                    enum: [
                        'LOGIN_SUCCESS',
                        'LOGIN_FAILED',
                        'PIN_CHANGED',
                        'TRANSFER_INITIATED',
                        'KYC_UPGRADED',
                        'FRAUD_FLAG'
                    ]
                },
                ts: {
                    bsonType: 'date'
                },
                details: {
                    bsonType: 'object'
                }
            }
        }
    },
    validationAction: 'error'
});

// The reference guide describes three validated collections, but its
// sample code omits a validator for login_sessions. This one requires
// the fields used by the later TTL-index demonstration.
nosql.createCollection('login_sessions', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'token', 'created_at'],
            properties: {
                customer_id: {
                    bsonType: 'number',
                    minimum: 1
                },
                token: {
                    bsonType: 'string'
                },
                created_at: {
                    bsonType: 'date'
                }
            }
        }
    },
    validationAction: 'error'
});

print('Portfolio collections created in CedarPay_db:');
portfolioCollections.forEach(function (name) {
    print('  - ' + name);
});

// Prove invalid KYC data is rejected. If it is unexpectedly accepted,
// remove the temporary test document.
try {
    const inserted = nosql.kyc_profiles.insertOne({
        customer_id: 1,
        status: 'MAYBE'
    });

    nosql.kyc_profiles.deleteOne({ _id: inserted.insertedId });
    print('FAIL: invalid KYC document was accepted; temporary test record removed');
} catch (error) {
    print(
        'PASS: invalid KYC document rejected -> ' +
        error.codeName +
        ' (code ' +
        error.code +
        ')'
    );
}// Portfolio 4: seed MongoDB with the same 5,000 regular CedarPay
// customers found in PostgreSQL. The settlement customer (ID 1) is excluded.
// CedarPay customer IDs are 2..5001.
// This creates 5,000 KYC profiles and 100,000 audit events.

const cedar = db.getSiblingDB('CedarPay_db');

const CUSTOMER_MIN = 2;
const CUSTOMER_MAX = 5001;
const CUSTOMERS = CUSTOMER_MAX - CUSTOMER_MIN + 1;
const EVENTS = 100000;
const BATCH = 5000;

// Deterministic random generator, so this dataset has a repeatable shape.
let seedState = 42;

function rnd() {
    seedState = (seedState * 1664525 + 1013904223) % 4294967296;
    return seedState / 4294967296;
}

function randInt(lo, hi) {
    return lo + Math.floor(rnd() * (hi - lo + 1));
}

function pick(arr) {
    return arr[Math.floor(rnd() * arr.length)];
}

function digits(n) {
    let value = '';
    for (let i = 0; i < n; i++) {
        value += String(Math.floor(rnd() * 10));
    }
    return value;
}

const NOW = Date.now();
const DAY = 24 * 60 * 60 * 1000;
const CITIES = ['Lagos', 'Abuja', 'Port Harcourt', 'Ibadan', 'Kano', 'Enugu', 'Benin City'];
const STATES = ['Lagos', 'FCT', 'Rivers', 'Oyo', 'Kano', 'Enugu', 'Edo'];
const DEVICES = ['Android', 'iPhone', 'Web'];
const DISCOS = ['Ikeja Electric', 'Eko Disco', 'AEDC', 'PHED'];

// This script clears only these two portfolio collections before reseeding.
// It leaves login_sessions and CedarPay_Database_Collection untouched.
cedar.kyc_profiles.deleteMany({});
cedar.audit_events.deleteMany({});

// Build KYC profiles for customer IDs 2 through 5001.
function makeDocument(type) {
    switch (type) {
        case 'BVN':
            return {
                type: 'BVN',
                number: digits(11),
                verified_with: 'NIBSS'
            };

        case 'NIN':
            return {
                type: 'NIN',
                number: digits(11),
                verified_with: 'NIMC'
            };

        case 'PASSPORT':
            return {
                type: 'PASSPORT',
                number: 'A' + digits(8),
                country: 'NG',
                expiry: new Date(NOW + randInt(200, 3000) * DAY)
            };

        case 'DRIVERS_LICENCE':
            return {
                type: 'DRIVERS_LICENCE',
                number: 'ABC' + digits(8) + 'XY',
                state_of_issue: pick(STATES),
                expiry: new Date(NOW + randInt(100, 1500) * DAY)
            };

        default:
            return {
                type: 'UTILITY_BILL',
                number: 'UB' + digits(8),
                provider: pick(DISCOS),
                issued_on: new Date(NOW - randInt(5, 80) * DAY)
            };
    }
}

let profiles = [];

for (let customerId = CUSTOMER_MIN; customerId <= CUSTOMER_MAX; customerId++) {
    const randomValue = rnd();
    const tier = randomValue < 0.55 ? 1 : (randomValue < 0.88 ? 2 : 3);
    const documents = [makeDocument('BVN')];

    if (tier >= 2) {
        documents.push(makeDocument(pick(['NIN', 'DRIVERS_LICENCE'])));
    }

    if (tier >= 3) {
        documents.push(makeDocument(pick(['PASSPORT', 'DRIVERS_LICENCE'])));
        documents.push(makeDocument('UTILITY_BILL'));
    }

    const profile = {
        customer_id: customerId,
        tier: tier,
        status: rnd() < 0.93 ? 'VERIFIED' : (rnd() < 0.5 ? 'PENDING' : 'REJECTED'),
        documents: documents,
        created_at: new Date(NOW - randInt(30, 700) * DAY)
    };

    // Optional fields vary between profiles to demonstrate flexible documents.
    if (tier === 3) {
        profile.risk_notes = 'Enhanced due diligence completed';
    }

    if (rnd() < 0.2) {
        profile.devices = [{
            platform: pick(DEVICES),
            first_seen: new Date(NOW - randInt(1, 400) * DAY)
        }];
    }

    profiles.push(profile);
}

cedar.kyc_profiles.insertMany(profiles);
profiles = null;

print('kyc_profiles inserted: ' + cedar.kyc_profiles.countDocuments({}));

// Create audit events only for the same regular CedarPay customer IDs.
function makeEvent() {
    const customer_id = randInt(CUSTOMER_MIN, CUSTOMER_MAX);
    const ts = new Date(NOW - Math.floor(rnd() * 90 * DAY));
    const randomValue = rnd();
    let event_type;
    let details;

    if (randomValue < 0.40) {
        event_type = 'LOGIN_SUCCESS';
        details = {
            ip: '102.89.' + randInt(0, 255) + '.' + randInt(1, 254),
            device: pick(DEVICES),
            city: pick(CITIES)
        };
    } else if (randomValue < 0.55) {
        event_type = 'LOGIN_FAILED';
        details = {
            ip: '41.58.' + randInt(0, 255) + '.' + randInt(1, 254),
            reason: pick([
                'WRONG_PIN',
                'WRONG_PIN',
                'DEVICE_NOT_RECOGNISED',
                'ACCOUNT_LOCKED'
            ])
        };
    } else if (randomValue < 0.60) {
        event_type = 'PIN_CHANGED';
        details = {
            channel: pick(['APP', 'USSD'])
        };
    } else if (randomValue < 0.90) {
        event_type = 'TRANSFER_INITIATED';
        details = {
            reference: 'ref-' + digits(10),
            amount: NumberDecimal((randInt(500, 500000) / 100).toFixed(2)),
            channel: pick(['APP', 'USSD', 'WEB'])
        };
    } else if (randomValue < 0.95) {
        event_type = 'KYC_UPGRADED';
        const from = randInt(1, 2);
        details = {
            from_tier: from,
            to_tier: from + 1
        };
    } else {
        event_type = 'FRAUD_FLAG';
        details = {
            rule: pick([
                'VELOCITY',
                'NEW_DEVICE_LARGE_AMOUNT',
                'MANY_FAILED_LOGINS'
            ]),
            score: randInt(40, 99)
        };
    }

    return {
        customer_id: customer_id,
        event_type: event_type,
        ts: ts,
        details: details
    };
}

// Insert in batches so the script doesn't hold all 100,000 events in memory.
for (let done = 0; done < EVENTS; done += BATCH) {
    const batch = [];

    for (let i = 0; i < BATCH; i++) {
        batch.push(makeEvent());
    }

    cedar.audit_events.insertMany(batch, { ordered: false });
    print('audit_events inserted so far: ' + (done + BATCH));
}

// Verify the totals and inspect a sample profile.
print('');
print('=== Verification ===');
print(
    'kyc_profiles : ' +
    cedar.kyc_profiles.countDocuments({}) +
    '  (expected ' +
    CUSTOMERS +
    ')'
);
print(
    'audit_events : ' +
    cedar.audit_events.countDocuments({}) +
    '  (expected ' +
    EVENTS +
    ')'
);

print('Events by type:');
cedar.audit_events.aggregate([
    { $group: { _id: '$event_type', count: { $sum: 1 } } },
    { $sort: { count: -1 } }
]).forEach(function (event) {
    print('  ' + event._id + ': ' + event.count);
});

print('Sample KYC profile (tier 3):');
printjson(cedar.kyc_profiles.findOne({ tier: 3 }));// Portfolio 4: CedarPay CRUD operations and aggregation pipelines.
// This script creates a temporary test customer, demonstrates CRUD,
// then cleans up that test customer and its test audit event.

const cedar = db.getSiblingDB('CedarPay_db');
const TEST_ID = 999999;

// Remove only a leftover test profile from an earlier run.
cedar.kyc_profiles.deleteMany({ customer_id: TEST_ID });

print('############ CRUD ############');

// CREATE: add a temporary customer with nested identity documents.
print('\n--- CREATE: onboard a test customer with a passport');
cedar.kyc_profiles.insertOne({
    customer_id: TEST_ID,
    tier: 2,
    status: 'PENDING',
    documents: [
        { type: 'BVN', number: '22212345678', verified_with: 'NIBSS' },
        {
            type: 'PASSPORT',
            number: 'A12345678',
            country: 'NG',
            expiry: new Date('2031-05-01')
        }
    ],
    created_at: new Date()
});

printjson(cedar.kyc_profiles.findOne(
    { customer_id: TEST_ID },
    { _id: 0 }
));

// READ: query a field inside the embedded documents array.
print('\n--- READ: tier 3 customers who hold a PASSPORT');
print(
    'count = ' +
    cedar.kyc_profiles.countDocuments({
        tier: 3,
        'documents.type': 'PASSPORT'
    })
);

// READ: use $elemMatch to match conditions on the same array document.
print('\n--- READ: passports expiring within the next 365 days');
print(
    'count = ' +
    cedar.kyc_profiles.countDocuments({
        documents: {
            $elemMatch: {
                type: 'PASSPORT',
                expiry: { $lt: new Date(Date.now() + 365 * 86400000) }
            }
        }
    })
);

// READ: fetch the newest three audit events for customer 1001.
print('\n--- READ: last 3 audit events for customer 1001');
cedar.audit_events
    .find({ customer_id: 1001 }, { _id: 0 })
    .sort({ ts: -1 })
    .limit(3)
    .forEach(function (event) {
        printjson(event);
    });

// UPDATE: change the temporary profile and add an identity document.
print('\n--- UPDATE: verify customer, upgrade tier, and add a document');
cedar.kyc_profiles.updateOne(
    { customer_id: TEST_ID },
    {
        $set: { status: 'VERIFIED', tier: 3 },
        $push: {
            documents: {
                type: 'UTILITY_BILL',
                number: 'UB99999999',
                provider: 'Eko Disco',
                issued_on: new Date()
            }
        }
    }
);

const updatedProfile = cedar.kyc_profiles.findOne({
    customer_id: TEST_ID
});

print(
    'status=' +
    updatedProfile.status +
    ', tier=' +
    updatedProfile.tier +
    ', documents=' +
    updatedProfile.documents.length
);

// Keep audit history append-only: record the upgrade as a new event.
print('\n--- UPDATE: record the change by inserting an audit event');
cedar.audit_events.insertOne({
    customer_id: TEST_ID,
    event_type: 'KYC_UPGRADED',
    ts: new Date(),
    details: { from_tier: 2, to_tier: 3 }
});

// DELETE: remove only the temporary test profile and test event.
print('\n--- DELETE: remove the temporary test customer');
const deletedProfile = cedar.kyc_profiles.deleteOne({
    customer_id: TEST_ID
});

print('deleted profile = ' + deletedProfile.deletedCount);

const deletedTestEvents = cedar.audit_events.deleteMany({
    customer_id: TEST_ID
});

print('deleted test audit events = ' + deletedTestEvents.deletedCount);

print('\n############ AGGREGATION ############');

// Aggregation 1: count events by type over the last 30 days.
print('\n--- Aggregation 1: events per type in the last 30 days');
cedar.audit_events.aggregate([
    {
        $match: {
            ts: { $gte: new Date(Date.now() - 30 * 86400000) }
        }
    },
    {
        $group: {
            _id: '$event_type',
            events: { $sum: 1 }
        }
    },
    {
        $sort: { events: -1 }
    }
]).forEach(function (result) {
    print('  ' + result._id + ': ' + result.events);
});

// Aggregation 2: total transfer amounts by day, showing the latest five days.
print('\n--- Aggregation 2: transfer amounts per day (latest 5 days)');
cedar.audit_events.aggregate([
    {
        $match: { event_type: 'TRANSFER_INITIATED' }
    },
    {
        $group: {
            _id: {
                $dateToString: {
                    format: '%Y-%m-%d',
                    date: '$ts'
                }
            },
            transfers: { $sum: 1 },
            total_amount: { $sum: '$details.amount' }
        }
    },
    {
        $sort: { _id: -1 }
    },
    {
        $limit: 5
    }
]).forEach(function (result) {
    print(
        '  ' +
        result._id +
        '  transfers=' +
        result.transfers +
        '  total=' +
        result.total_amount
    );
});

// Aggregation 3: use $lookup to join top failed-login customers to KYC profiles.
print('\n--- Aggregation 3: top 5 customers by failed logins with KYC tier');
cedar.audit_events.aggregate([
    {
        $match: { event_type: 'LOGIN_FAILED' }
    },
    {
        $group: {
            _id: '$customer_id',
            failed_logins: { $sum: 1 }
        }
    },
    {
        $sort: { failed_logins: -1, _id: 1 }
    },
    {
        $limit: 5
    },
    {
        $lookup: {
            from: 'kyc_profiles',
            localField: '_id',
            foreignField: 'customer_id',
            as: 'kyc'
        }
    },
    {
        $unwind: '$kyc'
    },
    {
        $project: {
            _id: 0,
            customer_id: '$_id',
            failed_logins: 1,
            tier: '$kyc.tier',
            status: '$kyc.status'
        }
    }
]).forEach(function (result) {
    printjson(result);
});

// Aggregation 4: average number of embedded identity documents per tier.
print('\n--- Aggregation 4: average documents per KYC tier');
cedar.kyc_profiles.aggregate([
    {
        $group: {
            _id: '$tier',
            customers: { $sum: 1 },
            avg_documents: { $avg: { $size: '$documents' } }
        }
    },
    {
        $sort: { _id: 1 }
    }
]).forEach(function (result) {
    print(
        '  tier ' +
        result._id +
        ': customers=' +
        result.customers +
        ', avg documents=' +
        result.avg_documents
    );
});// Portfolio 4: compare query plans before and after indexes.

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
});// CedarPay custom analysis: top cities by successful logins
// during the last 30 days, including distinct customers.

const cedar = db.getSiblingDB('CedarPay_db');

print('Top 5 cities by successful logins in the last 30 days:');

cedar.audit_events.aggregate([
    {
        $match: {
            event_type: 'LOGIN_SUCCESS',
            ts: { $gte: new Date(Date.now() - 30 * 86400000) }
        }
    },
    {
        $group: {
            _id: '$details.city',
            successful_logins: { $sum: 1 },
            customers: { $addToSet: '$customer_id' }
        }
    },
    {
        $project: {
            _id: 0,
            city: '$_id',
            successful_logins: 1,
            unique_customers: { $size: '$customers' }
        }
    },
    {
        $sort: { successful_logins: -1, city: 1 }
    },
    {
        $limit: 5
    }
]).forEach(function (result) {
    printjson(result);
});