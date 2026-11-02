# Portfolio 4: NoSQL Document Model Design – CedarPay

**Course:** MIT 8103 Advanced Database Systems  
**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  
**Target NoSQL Database:** MongoDB 7.0/8.0 (`CedarPay_db`)  

---

## 1. Document Modeling Strategy: Embedding vs. Referencing
In modeling CedarPay's operational data within MongoDB, the design adheres to document modeling best practices tailored to access patterns and document growth dynamics:

### 1.1 `kyc_profiles` Collection
- **Schema Pattern:** Hybrid Embedding.
- **Rationale:** A customer possesses multiple identity documents (e.g., NIN, BVN, Passport, Driver's License) and risk notes. In a relational database, these require multiple 1:M joined tables. In MongoDB, identity records are embedded as an array of subdocuments (`documents: [...]`) within the customer's KYC profile.
- **Bounding Growth:** Since identity documents per customer rarely exceed 5 items, embedding avoids document unbounded growth while allowing single-read retrieval of complete customer KYC status.
- **Validation:** Enforced via MongoDB `$jsonSchema` specifying required fields (`customer_id`, `kyc_tier`, `verification_status`), BSON types, and enum constraints (`TIER_1`, `TIER_2`, `TIER_3`).

### 1.2 `audit_events` Collection
- **Schema Pattern:** Flat Event Stream (Polymorphic Pattern).
- **Rationale:** Audit events are high-volume, append-only records representing disparate actions (logins, transfers, PIN changes, card locks). Each event shares common envelope fields (`event_id`, `customer_id`, `event_type`, `ip_address`, `city`, `created_at`), while event-specific payloads reside in a polymorphic `metadata` object.
- **Indexing:** Compound indexes on `{ customer_id: 1, created_at: -1 }` and `{ event_type: 1, created_at: -1 }` support sub-millisecond retrieval of recent security events.

### 1.3 `login_sessions` Collection
- **Schema Pattern:** Ephemeral Session Token Pattern with Time-To-Live (TTL).
- **Rationale:** Auth tokens expire after 30 days. Rather than running scheduled cron purge jobs, MongoDB's TTL index (`expireAfterSeconds: 2592000`) on `created_at` delegates automated background garbage collection to the database engine.

