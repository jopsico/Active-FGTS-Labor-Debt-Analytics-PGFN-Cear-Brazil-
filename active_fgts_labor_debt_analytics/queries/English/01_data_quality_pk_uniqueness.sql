/*
queries/01_data_quality_pk_uniqueness.sql
==============================================================================================================================
Business Question:
Is the natural key 'cpf_cnpj' strictly unique in the PGFN extraction, or do duplicate records exist for the same taxpayer?
If duplicates exist, how should the highest-impact record be prioritized and isolated?

Applied Technical Concepts:
- Common Table Expressions (CTEs) for modular query structuring
- Window Functions: ROW_NUMBER() with PARTITION BY and ORDER BY
- Canonical deduplication pattern in Data Warehouses
===============================================================================================================================
*/

WITH ranked_devedores AS (
SELECT
	cpf_cnpj,
	nome_devedor,
	nome_fantasia,
	valor_total,
	valor_divida_selecionada,
	ROW_NUMBER() OVER (
		PARTITION BY cpf_cnpj
		ORDER BY valor_divida_selecionada DESC, valor_total DESC
			) AS rn
		FROM stg_divida_fgts
	)
SELECT
	cpf_cnpj,
	nome_devedor,
	nome_fantasia,
	valor_total,
	valor_divida_selecionada,
	rn AS indice_duplicidade
FROM ranked_devedores
WHERE rn > 1
ORDER BY valor_divida_selecionada DESC;

/*
=================================================================================================================================================
-- Result: Query returned 0 rows. The natural primary key 'cpf_cnpj' is strictly unique across the exported dataset.
The official PGFN extract delivers debts pre-consolidated per taxpayer, confirming a 1-row-per-document granularity.

-- Pipeline & Downstream Impact:
  1. Zero risk of double counting across aggregated financial metrics
     (SUM, AVG) in subsequent queries.
  2. Eliminates the need for additional filtering or deduplication routines
     in downstream analytical layers.
==================================================================================================================================================
*/