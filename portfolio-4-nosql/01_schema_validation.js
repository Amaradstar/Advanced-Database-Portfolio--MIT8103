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
}