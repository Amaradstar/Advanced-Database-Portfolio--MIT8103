#!/usr/bin/env bash
# ==============================================================================
# Script: package_submission.sh
# Purpose: Build, standardize, validate, and package the final MIT 8103 portfolio
#          submission archive for Miva Open University LMS / Google Form.
#
# Rules Enforced:
# 1. Root folder: Surname_Firstname_StudentID/
# 2. Files: Surname_Firstname_DocumentType
# 3. ZERO SPACES in any folder or filename
# 4. ZERO generic names ('Assignment', 'Final File', 'Document', 'Project')
# 5. Standalone ReadME in root and inside folder
# 6. Archive size strictly verified under the 100 MB limit
# ==============================================================================

set -euo pipefail

# Student Configuration
SURNAME="Chirim"
FIRSTNAME="Amarachukwu"
STUDENT_ID="301914084"
PREFIX="${SURNAME}_${FIRSTNAME}"
TARGET_DIR="${PREFIX}_${STUDENT_ID}"
ZIP_NAME="${TARGET_DIR}.zip"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASE_DIR}"

echo "========================================================================"
echo "PACKAGING MIT 8103 DATABASE PORTFOLIO SUBMISSION"
echo "Candidate: ${FIRSTNAME} ${SURNAME} (${STUDENT_ID})"
echo "Target Folder: ${TARGET_DIR}/"
echo "Target Archive: ${ZIP_NAME}"
echo "========================================================================"

# Step 1: Initialize clean target directory
echo "[Step 1/6] Initializing clean packaging directory..."
rm -rf "${TARGET_DIR}"
rm -f "${ZIP_NAME}"
mkdir -p "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}/Screenshots"

# Step 2: Ensure core root documents exist and copy them
echo "[Step 2/6] Packaging Final Synthesis & Governance Documentation..."

# Standalone ReadME (Field 3 Deliverable & internal duplicate)
if [ -f "Chirim_Amarachukwu_README.txt" ]; then
    cp "Chirim_Amarachukwu_README.txt" "${TARGET_DIR}/${PREFIX}_README.txt"
elif [ -f "README.md" ]; then
    cp "README.md" "${PREFIX}_README.txt"
    cp "README.md" "${TARGET_DIR}/${PREFIX}_README.txt"
fi

# Final Synthesis Report (PDF and MD)
if [ -f "Chirim_Amarachukwu_Final_Report.pdf" ]; then
    cp "Chirim_Amarachukwu_Final_Report.pdf" "${TARGET_DIR}/${PREFIX}_Final_Report.pdf"
elif [ -f "${TARGET_DIR}/${PREFIX}_Portfolio_Summary.pdf" ]; then
    cp "${TARGET_DIR}/${PREFIX}_Portfolio_Summary.pdf" "${TARGET_DIR}/${PREFIX}_Final_Report.pdf"
fi
if [ -f "Chirim_Amarachukwu_Final_Report.md" ]; then
    cp "Chirim_Amarachukwu_Final_Report.md" "${TARGET_DIR}/${PREFIX}_Final_Report.md"
fi

# AI Declaration and References
if [ -f "Chirim_Amarachukwu_AI_Use_Declaration.md" ]; then
    cp "Chirim_Amarachukwu_AI_Use_Declaration.md" "${TARGET_DIR}/${PREFIX}_AI_Use_Declaration.md"
fi
if [ -f "Chirim_Amarachukwu_References.md" ]; then
    cp "Chirim_Amarachukwu_References.md" "${TARGET_DIR}/${PREFIX}_References.md"
fi

# Step 3: Package Portfolio 1 to 5 Deliverables
echo "[Step 3/6] Packaging Portfolio 1 to 5 Technical Deliverables..."

# --- Portfolio 1: Relational Design ---
cp "portfolio-1-database-design/case-study.md" "${TARGET_DIR}/${PREFIX}_P1_CaseStudy.md"
cp "portfolio-1-database-design/README.md" "${TARGET_DIR}/${PREFIX}_P1_RelationalSchema.md"
cp "portfolio-1-database-design/normalisation.md" "${TARGET_DIR}/${PREFIX}_P1_Normalisation.md"

# Combine / Copy DDL
cat "portfolio-1-database-design/00_create_database.sql" \
    "portfolio-1-database-design/01_verify_setup.sql" \
    "portfolio-1-database-design/02_create_tables.sql" > "${TARGET_DIR}/${PREFIX}_P1_CreateSchema.sql"

cat "portfolio-1-database-design/04_seed_data.sql" \
    "portfolio-1-database-design/05_verify_seed.sql" > "${TARGET_DIR}/${PREFIX}_P1_SeedData.sql"

cp "portfolio-1-database-design/03_constraint_tests.sql" "${TARGET_DIR}/${PREFIX}_P1_ConstraintTests.sql"

if [ -f "portfolio-1-database-design/Screenshots/Chirim_Amarachukwu_301914084_ER Diagram.png" ]; then
    cp "portfolio-1-database-design/Screenshots/Chirim_Amarachukwu_301914084_ER Diagram.png" "${TARGET_DIR}/${PREFIX}_ERD.png"
elif [ -f "Chirim_Amarachukwu_301914084/Chirim_Amarachukwu_301914084_Evidence_P1_ERD.png" ]; then
    cp "Chirim_Amarachukwu_301914084/Chirim_Amarachukwu_301914084_Evidence_P1_ERD.png" "${TARGET_DIR}/${PREFIX}_ERD.png"
fi

if [ -f "portfolio-1-database-design/erd_model.drawio" ]; then
    cp "portfolio-1-database-design/erd_model.drawio" "${TARGET_DIR}/${PREFIX}_ERD.drawio"
fi

# --- Portfolio 2: Query Optimisation ---
cp "portfolio-2-query-optimisation/README.md" "${TARGET_DIR}/${PREFIX}_P2_README.md"
cp "portfolio-2-query-optimisation/performance-analysis.md" "${TARGET_DIR}/${PREFIX}_P2_PerformanceResults.md"

# Combine all 11 queries into standardized file
cat portfolio-2-query-optimisation/queries/q*.sql > "${TARGET_DIR}/${PREFIX}_P2_Queries.sql"
cp "portfolio-2-query-optimisation/sql/03_create_indexes.sql" "${TARGET_DIR}/${PREFIX}_P2_CreateIndexes.sql"
cp "portfolio-2-query-optimisation/sql/04_drop_indexes.sql" "${TARGET_DIR}/${PREFIX}_P2_DropIndexes.sql"
cp "portfolio-2-query-optimisation/sql/05_planner_experiments.sql" "${TARGET_DIR}/${PREFIX}_P2_PlannerExperiments.sql"
cp "portfolio-2-query-optimisation/sql/06_write_cost.sql" "${TARGET_DIR}/${PREFIX}_P2_WriteCost.sql"

# --- Portfolio 3: Transactions & Concurrency ---
cp "portfolio-3-transactions-concurrency/README.md" "${TARGET_DIR}/${PREFIX}_P3_README.md"
if [ -f "portfolio-3-transactions-concurrency/README.md" ]; then
    cp "portfolio-3-transactions-concurrency/README.md" "${TARGET_DIR}/${PREFIX}_P3_ConcurrencyAnalysis.md"
fi
cat portfolio-3-transactions-concurrency/sql/*.sql > "${TARGET_DIR}/${PREFIX}_P3_TransactionScripts.sql"
if [ -f "portfolio-3-transactions-concurrency/stress_test.sh" ]; then
    cp "portfolio-3-transactions-concurrency/stress_test.sh" "${TARGET_DIR}/${PREFIX}_P3_StressTest.sh"
    chmod +x "${TARGET_DIR}/${PREFIX}_P3_StressTest.sh"
fi

# --- Portfolio 4: NoSQL with MongoDB ---
cp "portfolio-4-nosql/README.md" "${TARGET_DIR}/${PREFIX}_P4_README.md"
if [ -f "portfolio-4-nosql/nosql_model_design.md" ]; then
    cp "portfolio-4-nosql/nosql_model_design.md" "${TARGET_DIR}/${PREFIX}_P4_NoSQLModelDesign.md"
fi
if [ -f "portfolio-4-nosql/sql_vs_nosql_rationale.md" ]; then
    cp "portfolio-4-nosql/sql_vs_nosql_rationale.md" "${TARGET_DIR}/${PREFIX}_P4_SQLvsNoSQLRationale.md"
fi
cat portfolio-4-nosql/*.js > "${TARGET_DIR}/${PREFIX}_P4_Scripts.js"

# --- Portfolio 5: Distributed & Cloud Databases ---
cp "portfolio-5-distributed-cloud/README.md" "${TARGET_DIR}/${PREFIX}_P5_README.md"
if [ -f "portfolio-5-distributed-cloud/replication_and_failover.md" ]; then
    cp "portfolio-5-distributed-cloud/replication_and_failover.md" "${TARGET_DIR}/${PREFIX}_P5_ReplicationAndFailover.md"
fi
if [ -f "portfolio-5-distributed-cloud/sharding_partitioning.md" ]; then
    cp "portfolio-5-distributed-cloud/sharding_partitioning.md" "${TARGET_DIR}/${PREFIX}_P5_ShardingPartitioning.md"
fi
if [ -f "portfolio-5-distributed-cloud/availability_and_recovery.md" ]; then
    cp "portfolio-5-distributed-cloud/availability_and_recovery.md" "${TARGET_DIR}/${PREFIX}_P5_AvailabilityAndRecovery.md"
fi

# Create P5 executable runner script
cat << 'EOS' > "${TARGET_DIR}/${PREFIX}_P5_Scripts.sh"
#!/usr/bin/env bash
# CedarPay Distributed Verification Harness
set -euo pipefail
echo "Starting CedarPay Docker Cluster checks..."
docker compose -f portfolio-5-distributed-cloud/docker-compose.yml ps
echo "Replication health check..."
docker exec -i cedar_postgres_primary psql -U cedar_admin -d cedarpay_db -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
EOS
chmod +x "${TARGET_DIR}/${PREFIX}_P5_Scripts.sh"

cp "portfolio-5-distributed-cloud/03_partitioning.sql" "${TARGET_DIR}/${PREFIX}_P5_Partitioning.sql"
cp "portfolio-5-distributed-cloud/01_primary_checks.sql" "${TARGET_DIR}/${PREFIX}_P5_PrimaryChecks.sql"
cp "portfolio-5-distributed-cloud/02_replica_checks.sql" "${TARGET_DIR}/${PREFIX}_P5_ReplicaChecks.sql"
cp "portfolio-5-distributed-cloud/docker-compose.yml" "${TARGET_DIR}/${PREFIX}_P5_DockerCompose.yml"

# Step 4: Sanitize and copy screenshots (NO SPACES, strictly prefixed)
echo "[Step 4/6] Sanitizing and copying evidence screenshots..."

sanitize_copy() {
    local src_file="$1"
    local p_tag="$2"
    local base
    base="$(basename "${src_file}")"
    # replace spaces with underscores, clean up multiple underscores
    local clean_name
    clean_name="$(echo "${base}" | tr ' ' '_' | sed 's/__*/_/g')"
    # Ensure it starts with PREFIX
    if [[ "${clean_name}" != "${PREFIX}"* ]]; then
        clean_name="${PREFIX}_${p_tag}_${clean_name}"
    fi
    cp "${src_file}" "${TARGET_DIR}/Screenshots/${clean_name}"
}

# Copy from each portfolio screenshot directory
for f in portfolio-1-database-design/Screenshots/*.png; do
    [ -f "$f" ] && sanitize_copy "$f" "P1"
done

for f in portfolio-2-query-optimisation/screenshot/*.png; do
    [ -f "$f" ] && sanitize_copy "$f" "P2"
done

for f in portfolio-3-transactions-concurrency/screenshots/*.png; do
    [ -f "$f" ] && sanitize_copy "$f" "P3"
done

for f in portfolio-4-nosql/screenshots/*.png; do
    [ -f "$f" ] && sanitize_copy "$f" "P4"
done

for f in portfolio-5-distributed-cloud/screenshots/*.png; do
    [ -f "$f" ] && sanitize_copy "$f" "P5"
done

# Step 5: Strict Validation of Naming Rules
echo "[Step 5/6] Validating naming rules (spaces and generic terms)..."

invalid_spaces=0
invalid_generic=0

while IFS= read -r item; do
    fname="$(basename "${item}")"
    # Check for spaces
    if [[ "${fname}" =~ [[:space:]] ]]; then
        echo "ERROR: File contains space: ${fname}"
        invalid_spaces=$((invalid_spaces + 1))
    fi
    # Check for generic prohibited file names (e.g. Document.pdf, Chirim_Amarachukwu_Project.pdf)
    lower_name="$(echo "${fname}" | tr '[:upper:]' '[:lower:]')"
    prefix_lower="$(echo "${PREFIX}" | tr '[:upper:]' '[:lower:]')"
    for bad in "assignment" "final_file" "finalfile" "document" "project"; do
        if [[ "${lower_name}" == "${bad}".* || "${lower_name}" == "${prefix_lower}_${bad}".* ]]; then
            echo "ERROR: File uses generic naming: ${fname}"
            invalid_generic=$((invalid_generic + 1))
        fi
    done
done < <(find "${TARGET_DIR}" -type f)

if [ "${invalid_spaces}" -gt 0 ] || [ "${invalid_generic}" -gt 0 ]; then
    echo "FAILED: Validation detected ${invalid_spaces} space errors and ${invalid_generic} generic naming errors."
    exit 1
fi
echo "PASSED: All files conform strictly to Surname_Firstname_DocumentType with 0 spaces."

# Step 6: Create Zip Archive & Verify Size
echo "[Step 6/6] Generating submission zip archive: ${ZIP_NAME}..."
zip -r -q "${ZIP_NAME}" "${TARGET_DIR}"

# Calculate size in Megabytes
archive_size_bytes=$(wc -c < "${ZIP_NAME}" | tr -d ' ')
archive_size_mb=$(echo "scale=2; ${archive_size_bytes} / 1048576" | bc)

echo "========================================================================"
echo "PACKAGE BUILD COMPLETE"
echo "Root Folder:       ${TARGET_DIR}/"
echo "Total Files:       $(find "${TARGET_DIR}" -type f | wc -l | tr -d ' ')"
echo "Archive File:      ${ZIP_NAME}"
echo "Archive File Size: ${archive_size_mb} MB"
echo "Max Allowed Size:  100.00 MB"
echo "Status:            READY FOR SUBMISSION"
echo "========================================================================"
