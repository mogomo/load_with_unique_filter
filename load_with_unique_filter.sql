-- Cleanup the demo environment
DROP SCHEMA IF EXISTS UNIQUE_SCHEMA CASCADE;
CREATE SCHEMA UNIQUE_SCHEMA;
SET SEARCH_PATH TO UNIQUE_SCHEMA, public;

\echo
\echo === Step 1: Creating the target table with a UNIQUE constraint ===
\echo "Imagine we have a large fact table with a UNIQUE constraint on column f1:"
CREATE TABLE my_fact_table (
    f1 INT CONSTRAINT my_constraint_name UNIQUE ENABLED,
    f2 VARCHAR(100),
    f3 FLOAT
);

\echo
\echo === Step 2: Previewing the data we want to load ===
\echo "The CSV file we want to load includes duplicate values in column f1:"
\! cat /your_path/data.csv

\echo
\echo === Step 3: Attempting direct load into the target table ===
\echo "If we try to load the data directly into the table, the load will fail due to duplicate values:"
COPY my_fact_table
FROM '/home/dbadmin/ALL/TMP/UNIQUE_LOAD/data.csv'
DELIMITER ',';

\echo
\echo === Step 4: Using a staging table to handle duplicates ===
\echo "To safely handle duplicates, we first load the data into a staging table without any constraints:"
CREATE TEMPORARY TABLE staging_table_1 (
    f1 INT,
    f2 VARCHAR(100),
    f3 FLOAT
)
ON COMMIT PRESERVE ROWS KSAFE 0;

\echo
\echo "Loading all rows (including duplicates) into the staging table:"
COPY staging_table_1
FROM '/your_path/data.csv'
DELIMITER ','
ABORT ON ERROR;

\echo
\echo === Step 5 (Optional): Flagging unique and duplicate rows ===
\echo "To log which rows are unique and which are duplicates, we can create a second staging table with flags:"
CREATE TEMPORARY TABLE staging_table_2 ON COMMIT PRESERVE ROWS AS
WITH
  unique_list AS (
    SELECT *, TRUE AS _unique
    FROM staging_table_1
    LIMIT 1 OVER (PARTITION BY f1 ORDER BY f1)
  ),
  reject_list AS (
    SELECT d.*, FALSE AS _unique
    FROM staging_table_1 d
    LEFT JOIN unique_list u
      ON d.f1 = u.f1 AND d.f2 = u.f2 AND d.f3 = u.f3
    WHERE u.f1 IS NULL
  )
SELECT * FROM unique_list
UNION ALL
SELECT * FROM reject_list;

\echo
\echo "Rows that are considered unique and will be loaded:"
SELECT f1, f2, f3 FROM staging_table_2 WHERE _unique ORDER BY 1;

\echo
\echo "Rows that are considered duplicates and will be excluded:"
SELECT f1, f2, f3 FROM staging_table_2 WHERE NOT _unique ORDER BY 1;

\echo
\echo === Step 6: Loading only one row per f1 using analytic function ===
\echo "Alternatively, we can load only the first row per f1 directly from the first staging table without logging:"
INSERT INTO my_fact_table
SELECT * FROM staging_table_1
LIMIT 1 OVER (PARTITION BY f1 ORDER BY f1);

COMMIT;

\echo
\echo === Final Result ===
\echo "This is the final content of the target table after loading unique rows:"
SELECT * FROM my_fact_table ORDER BY f1;
