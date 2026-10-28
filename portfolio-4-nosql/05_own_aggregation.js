// CedarPay custom analysis: top cities by successful logins
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