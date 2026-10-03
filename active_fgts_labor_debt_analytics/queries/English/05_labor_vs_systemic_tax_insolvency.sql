/*
queries/05_labor_vs_systemic_tax_insolvency.sql
============================================================================================================
Business Questions:
What is the proportion of FGTS debt relative to the total consolidated federal liability?
How many taxpayers maintain an exclusively labor-related debt (100% FGTS) versus 
how many utilize unremitted employee deposits as operational capital amidst systemic fiscal insolvency (< 10%)?

Applied Technical Concepts:
- Numerical Safeguards: NULLIF(valor_total, 0) to eliminate division-by-zero exceptions
- Categorical Bucketing: CASE WHEN evaluating discrete percentage share thresholds
- Modular CTEs: Clear architectural separation between row-level share computation, cohort aggregation, and portfolio weighting
- Window Functions: SUM(...) OVER () to dynamically calculate percentage distributions of debtors and capital
============================================================================================================
*/

WITH devedores_com_share AS (
    SELECT
        cpf_cnpj,
        nome_devedor,
        valor_divida_selecionada,
        valor_total,
        ROUND((valor_divida_selecionada / NULLIF(valor_total, 0)) * 100.0, 2) AS pct_fgts,
        CASE
            WHEN valor_divida_selecionada >= valor_total THEN '1. Exclusivo FGTS (100%)'
            WHEN (valor_divida_selecionada / NULLIF(valor_total, 0)) >= 0.50 THEN '2. Majoritário (50% a 99%)'
            WHEN (valor_divida_selecionada / NULLIF(valor_total, 0)) >= 0.10 THEN '3. Relevante (10% a 49%)'
            ELSE '4. Residual / Sistêmico (< 10%)'
        END AS perfil_divida
    FROM stg_divida_fgts
),
agrupamento_perfis AS (
    SELECT
        perfil_divida,
        COUNT(*) AS total_devedores,
        ROUND(SUM(valor_divida_selecionada), 2) AS montante_fgts,
        ROUND(SUM(valor_total), 2) AS montante_uniao,
        ROUND(AVG(valor_divida_selecionada), 2) AS ticket_medio_fgts,
        ROUND(MEDIAN(valor_divida_selecionada), 2) AS mediana_fgts
    FROM devedores_com_share
    GROUP BY perfil_divida
)
SELECT
    perfil_divida,
    total_devedores,
    ROUND((total_devedores * 100.0) / SUM(total_devedores) OVER (), 2) AS pct_devedores,
    montante_fgts,
    ROUND((montante_fgts * 100.0) / SUM(montante_fgts) OVER (), 2) AS pct_montante_fgts,
    montante_uniao,
    ticket_medio_fgts,
    mediana_fgts
FROM agrupamento_perfis
ORDER BY perfil_divida ASC;

/*
==============================================================================================================================
-- Query Results & Execution Diagnostics:
- Delinquency Profile Distribution:
  1. Exclusively FGTS (100%):       357 debtors (34.29%) | FGTS: R$  40.64M (13.99%) | Federal: R$   40.64M | Median: R$  9.5K
  2. Majority FGTS (50% to 99%):     97 debtors ( 9.32%) | FGTS: R$  14.31M ( 4.93%) | Federal: R$   18.00M | Median: R$ 55.5K
  3. Relevant FGTS (10% to 49%):    182 debtors (17.48%) | FGTS: R$  93.10M (32.05%) | Federal: R$  451.64M | Median: R$ 65.5K
  4. Residual / Systemic (< 10%):   405 debtors (38.90%) | FGTS: R$ 142.43M (49.03%) | Federal: R$ 7,864.67M | Median: R$ 28.5K

- Business Insights & Debt Collection Strategy:
  * Critical Bipolarity:
    - 34.29% of debtors have liabilities strictly confined to FGTS (isolated labor liabilities).
    - Nearly half of the total FGTS deficit (49.03%) is locked within the 'Residual / Systemic' cohort,
      where debtors accumulate R$ 7.86 billion in total federal tax liabilities.
  * Credit Recovery Intelligence:
    - Amicable administrative settlements and targeted FGTS transaction programs have high conversion 
      viability in Cohort 1 (median debt of R$ 9.5K with zero competing federal tax liens).
    - In Cohort 4, standalone FGTS enforcement actions have low recovery efficacy without coordinated 
      tax foreclosures and corporate veil piercing, given the systemic state of commercial insolvency.
===============================================================================================================================
*/