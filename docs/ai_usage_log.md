# AI Usage Log

Date | Tool | What I asked for | Used in | Modified? | What I learned
-----------|-----------|------------------------------------------|------------------|-----------|------------------------------
2026-06-20 | Claude | Full database schema design (20 tables, FKs, constraints) | database/HiSUP_DB_Script.sql | Yes - fixed ON UPDATE CASCADE conflicts myself in SSMS error cycle | SQL Server blocks multiple cascade paths converging on one table; fixed by switching ON UPDATE to NO ACTION
2026-06-20 | Claude | ERD design guidance (entities, relationships, cardinalities) | docs/erd.png | No - used as designed | How to structure a 20-table university schema and where bridge tables (Enrollments) are needed
