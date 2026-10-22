
-- Q10: Customer KYC Verification Analysis
-- Topic: KYC Verification Status and Aggregation
-- Business question:
-- How many customers have verified, pending, or rejected KYC records?

SELECT
    k.verification_status,
    COUNT(DISTINCT k.customer_id) AS total_customers,
    COUNT(k.kyc_id) AS total_kyc_records
FROM kyc_records AS k
GROUP BY k.verification_status
ORDER BY total_customers DESC;
