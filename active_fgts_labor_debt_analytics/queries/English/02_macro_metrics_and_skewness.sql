/*
queries/02_macro_metrics_and_skewness.sql
===========================================================================================================
Business Questions:
What is the total volume of records and consolidated amount of delinquent FGTS debt in Ceará?
How is this liability distributed across taxpayers (Mean vs. Median skewness)?
What proportion does the FGTS debt represent relative to the total federal debt owed by these taxpayers?

Applied Technical Concepts:
- Numeric Aggregations: COUNT, COUNT DISTINCT, SUM, MIN, MAX
- Descriptive Statistics: AVG, MEDIAN, STDDEV_SAMP (DuckDB native)
- Derived Metrics & Proportions with ROUND
===========================================================================================================
*/

SELECT
-- Volumetria de registros e devedores
COUNT (*) AS total_registros,
COUNT (DISTINCT cpf_cnpj) AS devedores_unicos,

--Montantes financeiros totais
ROUND(SUM(valor_divida_selecionada), 2) AS montante_total_fgts,
ROUND(SUM(valor_total), 2) AS montante_divida_total_uniao,

--Representatividade do FGTS frente ao passivo total com a União (%)
ROUND(
	(SUM(valor_divida_selecionada) / SUM(valor_total)) * 100, 2
) AS pct_fgts_sobre_total,

-- Medidas de Tendência Central (Média vs. Mediana)
ROUND(AVG(valor_divida_selecionada), 2) AS ticket_medio_fgts,
ROUND(MEDIAN(valor_divida_selecionada), 2) AS mediana_fgts,

-- Medidas de Dispersão e Limites
ROUND(MIN(valor_divida_selecionada), 2) AS menor_divida_fgts,
ROUND(MAX(valor_divida_selecionada), 2) AS maior_divida_fgts,
ROUND(STDDEV_SAMP(valor_divida_selecionada), 2) AS desvio_padrao_fgts
FROM stg_divida_fgts;

/*
====================================================================================================================================================
-- Query Results & Execution Diagnostics:
- Record Volumetrics:
  * Total Records: 1,041
  * Unique Taxpayers: 1,041 (1:1 key integrity verified via Query 01)

- Financial Scale & Aggregate Exposure:
  * Total Active FGTS Debt: R$ 290,484,549.29 (~R$ 290.5M)
  * Total Consolidated Federal Debt: R$ 8,374,951,636.51 (~R$ 8.37B)
  * FGTS Share of Total: 3.47% of total consolidated federal liability

- Dispersion & Skewness Metrics:
  * Minimum FGTS Debt: R$ 12.75 (Administrative residual balance)
  * Maximum FGTS Debt: R$ 30,384,575.14 (Severe single-debtor peak concentration)
  * Mean Debt (Average): R$ 279,043.76
  * Median Debt: R$ 28,896.98
  * Sample Standard Deviation: R$ 1,719,392.31 (Coefficient of Variation > 600%)

- Analytical & Business Takeaways:
  The liability distribution exhibits severe positive right-skewness. The arithmetic mean 
  is heavily distorted by high-value outliers in the upper tail. The median (R$ 28.9K) 
  accurately represents the typical debtor profile. Furthermore, FGTS debt constitutes 
  only 3.47% of the total liabilities owed to the federal government, indicating that 
  labor guarantee defaults are fundamentally a secondary symptom of systemic fiscal insolvency.
====================================================================================================================================================
*/