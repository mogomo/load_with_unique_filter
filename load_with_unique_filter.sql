-- Cleanup the demo environment
DROP SCHEMA IF EXISTS UNIQUE_SCHEMA CASCADE;
CREATE SCHEMA UNIQUE_SCHEMA;
SET SEARCH_PATH TO UNIQUE_SCHEMA, public;

\echo
\echo === Step 1: Creating the target table with a UNIQUE constraint ===
\echo Imagine we have a large fact table with a UNIQUE constraint on column f1:
CREATE TABLE my_fact_table (
    f1 INT CONSTRAINT my_constraint_name UNIQUE ENABLED,
    f2 VARCHAR(100),
    f3 FLOAT)
ORDER BY f1
SEGMENTED BY hash(f1) ALL NODES;

\echo
\echo === Step 2: Previewing the data we want to load ===
\echo The CSV file we want to load includes duplicate values in column f1:
\! echo -e "1,new_one,1.1\n2,new_two,2.1\n1,new_three,3.1\n3,new_four,4.1\n4,new_five,5.1\n2,new_six,6.1" > /home/dbadmin/ALL/UNIQUE_LOAD/data.csv
\! cat /home/dbadmin/ALL/UNIQUE_LOAD/data.csv

\echo
\echo === Step 3: Attempting direct load into the target table ===
\echo If we try to load the data directly into the table, the load will fail due to duplicate values:
COPY my_fact_table
FROM '/home/dbadmin/ALL/UNIQUE_LOAD/data.csv'
DELIMITER ',';

\echo
\echo === Step 4: Using a staging table to handle duplicates ===
\echo To safely handle duplicates, we first load the data into a staging table without any constraints:
CREATE TEMPORARY TABLE staging_table_1 (
    f1 INT,
    f2 VARCHAR(100),
    f3 FLOAT
)
ON COMMIT PRESERVE ROWS KSAFE 0;

\echo
\echo Loading all rows (including duplicates) into the staging table:
COPY staging_table_1
FROM '/home/dbadmin/ALL/UNIQUE_LOAD/data.csv'
DELIMITER ','
ABORT ON ERROR;

\echo
\echo === Step 5 (Optional): Flagging unique and duplicate rows ===
\echo To log which rows are unique and which are duplicates, we can create a second staging table with flags:
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
\echo Rows that are considered unique and will be loaded:
SELECT f1, f2, f3 FROM staging_table_2 WHERE _unique ORDER BY 1;

\echo
\echo Rows that are considered duplicates and will be excluded:
SELECT f1, f2, f3 FROM staging_table_2 WHERE NOT _unique ORDER BY 1;

\echo
\echo === Step 6: Loading only one row per f1 using analytic function ===
\echo Alternatively, we can load only the first row per f1 directly from the first staging table without logging:
INSERT INTO my_fact_table
SELECT * FROM staging_table_1
LIMIT 1 OVER (PARTITION BY f1 ORDER BY f1);

COMMIT;

\echo
\echo This is the content of the target table after loading rows with unique "f1" values:
SELECT * FROM my_fact_table ORDER BY f1;
--  f1 |    f2    | f3
-- ----+----------+-----
--   1 | new_one  | 1.1
--   2 | new_two  | 2.1
--   3 | new_four | 4.1
--   4 | new_five | 5.1
-- (4 rows)


\echo
\echo An additional challenge arises when some of the "f1" values already exist in the target fact table,
\echo and we want to avoid failing the load or inserting duplicates.
\echo In such cases, we can extend the filtering logic by performing an anti-join from the staging table to the fact table.
\echo To demonstrate this example, we will first clean the fact table and then load one million values into it.
\echo The one million values are all greater than 3, to demonstrate "f1 = 4" as a duplicate value.

TRUNCATE TABLE my_fact_table;

\set DEMO_ROWS 1000000
\set MIN_VALUE 4
INSERT INTO my_fact_table
with myrows as (select
row_number() over() + :MIN_VALUE -1 as f1
from ( select 1 from ( select now() as se union all
select now() + :DEMO_ROWS - 1 as se) a timeseries ts as '1 day' over (order by se)) b)
select f1, 'old_' || f1 as f2, f1 + 0.1 as f3
from myrows
order by f1;
COMMIT;

\echo
\echo The following ensures that only truly new and unique keys (i.e., those not already present in the target) are considered for insertion.
INSERT INTO my_fact_table
SELECT s.*
FROM (
  SELECT * FROM staging_table_1
  LIMIT 1 OVER (PARTITION BY f1 ORDER BY f1)
) s
LEFT JOIN my_fact_table t ON s.f1 = t.f1
WHERE t.f1 IS NULL;
COMMIT;

\echo === Final Result ===
\echo This is the final content of the first 6 lines in the target table after loading "new_" rows with unique "f1" values:
SELECT * FROM my_fact_table ORDER BY f1 limit 6;
