ASTERPEAK POSTGRES IMPORT BUNDLE

What is in here
---------------
- asterpeak_raw_schema.sql : creates the 14 raw CRM tables, keys, relationships, and useful indexes
- one CSV file for each table in the AsterPeak synthetic CRM dataset

Why the schema is called "raw"
------------------------------
The dataset intentionally contains CRM problems (missing values, routing errors, stale pipeline,
forecast mismatches, etc.). We do NOT enforce every business-required field as a database NOT NULL
constraint, because that would stop the bad raw records from loading. We want to load them first,
then find them with SQL.

Recommended next steps in DBeaver/PostgreSQL
---------------------------------------------
1. Create a PostgreSQL database named: asterpeak_revops
2. Open a SQL Editor connected to that database.
3. Run asterpeak_raw_schema.sql.
4. Import the CSVs into the matching raw.<table_name> tables.
5. Import parent/reference tables first:
   territories
   states
   users
   products
   accounts
   contacts
   leads
   opportunities
   opportunity_stage_history
   activities
   opportunity_products
   deal_approvals
   opportunity_close_date_history
   opportunity_forecast_snapshots

Do not worry about writing analysis SQL yet. Once the tables are loaded, the next project phase
is validating the database and then running the CRM/data-quality audit.
