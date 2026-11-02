
-- MIT 8103 Advanced Database Systems
-- CedarPay Portfolio 2
-- File: 06_write_cost.sql
-- Purpose: Demonstrate the storage and write overhead of indexes.
--
-- This experiment uses temporary tables and does not modify
-- the original CedarPay tables.
--
-- Run in the same database where ledger_entries exists.

-- ============================================================
-- PART A: Create a copy without secondary indexes
-- ============================================================

DROP TABLE IF EXISTS le_no_index;
DROP TABLE IF EXISTS le_with_index;

CREATE TEMP TABLE le_no_index
    (LIKE ledger_entries INCLUDING DEFAULTS);


-- ============================================================
-- PART B: Create a copy with candidate secondary indexes
-- ============================================================

CREATE TEMP TABLE le_with_index
    (LIKE ledger_entries INCLUDING DEFAULTS);

-- Q1: Account statement
CREATE INDEX tmp_le_account_created
    ON le_with_index (account_id, created_at DESC);

-- Q4: Large debit entries for fraud review
CREATE INDEX tmp_le_large_debits
    ON le_with_index (created_at)
    INCLUDE (account_id, amount)
    WHERE direction = 'DEBIT'
      AND amount >= 4000;


-- ============================================================
-- PART C: Measure insertion time
-- Use psql's \timing command for elapsed-time measurements.
-- ============================================================

\timing on

-- Insert into the table without secondary indexes.
INSERT INTO le_no_index
SELECT *
FROM ledger_entries;

-- Insert into the table with secondary indexes.
INSERT INTO le_with_index
SELECT *
FROM ledger_entries;


-- ============================================================
-- PART D: Compare row counts and total storage
-- ============================================================

SELECT
    'no secondary indexes' AS table_type,
    COUNT(*) AS row_count,
    pg_size_pretty(
        pg_total_relation_size('le_no_index')
    ) AS total_size
FROM le_no_index

UNION ALL

SELECT
    'with secondary indexes' AS table_type,
    COUNT(*) AS row_count,
    pg_size_pretty(
        pg_total_relation_size('le_with_index')
    ) AS total_size
FROM le_with_index;


-- ============================================================
-- PART E: Compare table and index storage separately
-- ============================================================

SELECT
    tablename,
    pg_size_pretty(
        pg_relation_size(
            CASE tablename
                WHEN 'le_no_index' THEN 'le_no_index'::regclass
                WHEN 'le_with_index' THEN 'le_with_index'::regclass
            END
        )
    ) AS table_size,
    pg_size_pretty(
        pg_indexes_size(
            CASE tablename
                WHEN 'le_no_index' THEN 'le_no_index'::regclass
                WHEN 'le_with_index' THEN 'le_with_index'::regclass
            END
        )
    ) AS indexes_size,
    pg_size_pretty(
        pg_total_relation_size(
            CASE tablename
                WHEN 'le_no_index' THEN 'le_no_index'::regclass
                WHEN 'le_with_index' THEN 'le_with_index'::regclass
            END
        )
    ) AS total_size
FROM (
    VALUES
        ('le_no_index'),
        ('le_with_index')
) AS t(tablename)
ORDER BY tablename;


-- ============================================================
-- PART F: Clean up temporary tables
-- ============================================================

DROP TABLE le_no_index;
DROP TABLE le_with_index;

\timing off
