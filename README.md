
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
```
1,new_one,1.1  
2,new_two,2.1  
1,new_three,3.1  
3,new_four,4.1  
4,new_five,5.1  
2,new_six,6.1  
```

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
- Filters to keep only one row per duplicate key using analytic SQL
- Optionally logs accepted vs. rejected rows
- Inserts only the valid rows into the final table

------------------------------------------------------------------

## This is the final content of the first 6 lines in the target table after loading "new_" rows with unique "f1" values:
```
 f1 |    f2    | f3  
----+----------+-----  
  1 | new_one  | 1.1  
  2 | new_two  | 2.1  
  3 | new_four | 4.1  
  4 | old_4    | 4.1  
  5 | old_5    | 5.1  
  6 | old_6    | 6.1  
(6 rows)  
```
------------------------------------------------------------------
