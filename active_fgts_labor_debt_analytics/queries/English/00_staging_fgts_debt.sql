/*
-- queries/00_staging_fgts_debt.sql
===================================================================================================================
Layer: Staging (Silver Layer / ELT)
Objective:
Standardize and sanitize the raw FGTS delinquent debtor dataset (PGFN - Ceará).
Normalizes column identifiers to snake_case, strips trailing/leading whitespace, 
casts missing metadata into canonical SQL NULLs, and parses Brazilian Real (BRL) currency strings 
into exact fixed-point numeric types.

Technical Concepts & Architectural Decisions:
- ELT Paradigm: Raw extraction preserved as-is; data transformations version-controlled in SQL
- String Manipulation: TRIM and NULLIF for cadastral integrity and canonical null handling
- Financial Data Typing: Chained REPLACE operations paired with TRY_CAST to enforce DECIMAL(18, 2)
===================================================================================================================
*/

CREATE OR REPLACE VIEW stg_divida_fgts AS
SELECT
    TRIM("CPF/CNPJ") AS cpf_cnpj,
    TRIM("Nome") AS nome_devedor,
    NULLIF(TRIM("Nome Fantasia"), '') AS nome_fantasia,
    TRY_CAST(REPLACE(REPLACE(TRIM("Valor Total"), '.', ''), ',', '.') AS DECIMAL(18, 2)) AS valor_total,
    TRY_CAST(REPLACE(REPLACE(TRIM("Valor da Dívida Selecionada"), '.', ''), ',', '.') AS DECIMAL(18, 2)) AS valor_divida_selecionada
FROM divida_fgts;

/*
-- Technical Notes & Architectural Impact:
============================================================================
1. Separation of Concerns (DRY - Don't Repeat Yourself):
   Materializing this View eliminates redundant CAST and REPLACE operations 
   across downstream analytical queries, centralizing data sanitization logic 
   within a single catalog object.

2. Financial Precision (DECIMAL vs. FLOAT):
   Explicitly enforcing DECIMAL(18, 2) prevents penny-rounding discrepancies 
   caused by binary floating-point arithmetic errors during aggregation operations (SUM, AVG).

3. Pipeline Resilience (TRY_CAST):
   Unlike standard CAST, TRY_CAST gracefully degrades parsing failures to NULL 
   without breaking downstream query execution when corrupted records occur.
==============================================================================
*/