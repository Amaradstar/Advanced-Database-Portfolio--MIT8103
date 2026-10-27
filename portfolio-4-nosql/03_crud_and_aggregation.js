// Portfolio 4: CedarPay CRUD operations and aggregation pipelines.
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
});