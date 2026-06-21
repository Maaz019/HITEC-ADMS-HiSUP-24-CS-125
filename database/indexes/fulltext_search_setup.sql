-- ============================================================
-- Full-Text Search on LibraryItems
-- Required by Module 3: the library search page must use
-- CONTAINS or FREETEXT, not a double-wildcard LIKE.
-- ============================================================
USE HiSUP_DB;
GO

-- ---- Step 1: Find the actual name of the primary key constraint
-- on LibraryItems (needed for the next step - PK constraint names
-- are auto-generated and differ per machine) ----
SELECT name AS PrimaryKeyConstraintName
FROM sys.key_constraints
WHERE type = 'PK' AND OBJECT_NAME(parent_object_id) = 'LibraryItems';
GO

-- ---- Step 2: Create a full-text catalog (a container for the index) ----
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = 'HiSUP_FTCatalog')
BEGIN
    CREATE FULLTEXT CATALOG HiSUP_FTCatalog AS DEFAULT;
END
GO

-- ---- Step 3: Create the full-text index on Title and Author ----
-- IMPORTANT: replace 'YOUR_PK_CONSTRAINT_NAME_HERE' below with the
-- actual name returned by the query in Step 1 before running this.
-- Full-text indexes require a unique, single-column, non-nullable
-- index to exist on the table first - the PK on ItemID satisfies this.
/*
CREATE FULLTEXT INDEX ON LibraryItems (Title, Author)
KEY INDEX YOUR_PK_CONSTRAINT_NAME_HERE
ON HiSUP_FTCatalog
WITH CHANGE_TRACKING AUTO;
*/
GO

-- ============================================================
-- Test it - CONTAINS (exact word/phrase matching, supports
-- boolean operators like AND/OR/NEAR) - run only after the
-- CREATE FULLTEXT INDEX above has been uncommented and executed
-- ============================================================
-- SELECT ItemID, Title, Author
-- FROM LibraryItems
-- WHERE CONTAINS((Title, Author), 'Database OR Networks');
-- GO

-- ============================================================
-- Test it - FREETEXT (meaning-based match, more forgiving -
-- matches word forms/inflections, not exact phrases)
-- ============================================================
-- SELECT ItemID, Title, Author
-- FROM LibraryItems
-- WHERE FREETEXT((Title, Author), 'database systems fundamentals');
-- GO

-- ============================================================
-- Compare: this is what the brief explicitly forbids for the
-- search page (double-wildcard LIKE) - shown here only to
-- contrast with CONTAINS/FREETEXT, not for actual use in the app
-- ============================================================
-- SELECT ItemID, Title, Author FROM LibraryItems WHERE Title LIKE '%database%';
