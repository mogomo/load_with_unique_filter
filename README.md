
# Vertica Demo: Handling Duplicates with a UNIQUE Constraint

The provided script demonstrates how to safely load data with duplicate keys into a Vertica table that enforces a UNIQUE constraint by using a staging table and filtering to retain only one occurrence per key.

------------------------------------------------------------------

## Disclaimer:

This code is provided "as is" without any warranties or guarantees. 
It is intended for educational and demonstration purposes only. 
Always review and test in a QA or non-production environment before using in a live system.

------------------------------------------------------------------

## Files Included:

- load_with_unique_filter.sql   : Main SQL script demonstrating the full loading and filtering process.

------------------------------------------------------------------

## Prerequisites:

1. A running Vertica environment.
2. Create a sample CSV file at the following path:  /your_path/data.csv

## Sample contents of data.csv:

1,one,1.1  
2,two,2.1  
1,three,3.1  
3,four,4.1  
4,five,5.1  
2,six,6.1  

------------------------------------------------------------------

# How to Run the Demo:

## Run the script using the following command:
```
  vsql -f load_with_unique_filter.sql
```

## What it does:
- Creates a schema and a target table with a UNIQUE constraint
- Attempts to load duplicate data and fails (by design)
- Loads the same data into a staging table with no constraints
- Filters to keep only the first row per duplicate key using analytic SQL
- Optionally logs accepted vs. rejected rows
- Inserts only the valid rows into the final table

------------------------------------------------------------------

## Final Output Example (target table contents):

 f1 |  f2   | f3
----+-------+-----
  1 | three | 3.1
  2 | six   | 6.1
  3 | four  | 4.1
  4 | five  | 5.1
(4 rows)

------------------------------------------------------------------
