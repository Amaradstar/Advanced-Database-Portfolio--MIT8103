const cedar = db.getSiblingDB('CedarPay_db');
const topology = db.hello();

print('=== Atlas replica set topology ===');
print('Replica set: ' + topology.setName);
print('Members discovered: ' + topology.hosts.length);
print('Primary: ' + topology.primary);

const marker = {
    purpose: 'Portfolio 5 majority write and secondary read check',
    created_at: new Date()
};

const writeResult = cedar.p5_replication_demo.insertOne(marker, {
    writeConcern: {
        w: 'majority',
        wtimeout: 10000
    }
});

print('');
print('=== Majority write ===');
print('Acknowledged: ' + writeResult.acknowledged);
print('Marker ID: ' + writeResult.insertedId);

const readBack = cedar.p5_replication_demo
    .find({ _id: writeResult.insertedId })
    .readPref('secondary')
    .readConcern('majority')
    .toArray();

print('');
print('=== Secondary read with majority read concern ===');
print('Documents returned: ' + readBack.length);
if (readBack.length !== 1) {
    throw new Error('The marker was not returned by the secondary read.');
}
printjson(readBack[0]);

const cleanup = cedar.p5_replication_demo.deleteOne(
    { _id: writeResult.insertedId },
    { writeConcern: { w: 'majority' } }
);

print('');
print('=== Cleanup ===');
print('Temporary marker deleted: ' + (cleanup.deletedCount === 1));