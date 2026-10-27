// Portfolio 4: seed MongoDB with the same 5,000 regular CedarPay
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
printjson(cedar.kyc_profiles.findOne({ tier: 3 }));