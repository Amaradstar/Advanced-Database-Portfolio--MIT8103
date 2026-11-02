const cedar = db.getSiblingDB('CedarPay_db');
const loginFilter = { event_type: 'LOGIN_SUCCESS' };

function countOnMember(readPreference) {
    return cedar.audit_events
        .find(loginFilter, { _id: 1 })
        .readPref(readPreference)
        .readConcern('majority')
        .itcount();
}

print('=== Successful login count by read preference ===');

const primaryCount = countOnMember('primary');
print('Primary count:   ' + primaryCount);

const secondaryCount = countOnMember('secondary');
print('Secondary count: ' + secondaryCount);

print('Counts match: ' + (primaryCount === secondaryCount));

if (primaryCount !== secondaryCount) {
    throw new Error('Primary and secondary counts do not match.');
}