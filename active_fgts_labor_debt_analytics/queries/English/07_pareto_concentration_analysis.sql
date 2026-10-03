/*
queries/07_pareto_concentration_analysis.sql
=========================================================================================================
Business Questions:
What is the degree of concentration of active FGTS debt in Ceará under Pareto's Principle?
How many top-ranked debtors (absolute ranking) account for 50% and 80% of the aggregate liability?
What are the distinct characteristics of the hyper-concentrated tier versus the judicial long tail?

Applied Technical Concepts:
- Analytical Window Frames: SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
- Deterministic Ranking: ROW_NUMBER() for strict ordering by outstanding financial volume
- Cumulative Running Totals: Dynamic computation of cumulative percentages against the global portfolio
- Pareto Bucketing: Conditional classification (CASE WHEN) into executive cutoff cohorts
=========================================================================================================
*/

WITH devedores_ranqueados AS (
    SELECT
        cpf_cnpj,
        nome_devedor,
        valor_divida_selecionada,
        ROW_NUMBER() OVER (
            ORDER BY valor_divida_selecionada DESC
        ) AS ranking,
        -- Soma acumulada linha a linha a partir do topo até o registro atual
        SUM(valor_divida_selecionada) OVER (
            ORDER BY valor_divida_selecionada DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS soma_acumulada_fgts,
        -- Montante total da base inteira capturado em janela única
        SUM(valor_divida_selecionada) OVER () AS montante_global_fgts
    FROM stg_divida_fgts
),
classificacao_pareto AS (
    SELECT
        cpf_cnpj,
        nome_devedor,
        ranking,
        valor_divida_selecionada,
        soma_acumulada_fgts,
        ROUND((soma_acumulada_fgts / montante_global_fgts) * 100.0, 2) AS pct_acumulado_fgts,
        CASE
            WHEN (soma_acumulada_fgts / montante_global_fgts) <= 0.50 THEN '1. Top 50% (Hiperconcentrado)'
            WHEN (soma_acumulada_fgts / montante_global_fgts) <= 0.80 THEN '2. Faixa 50% a 80% (Pareto Core)'
            ELSE '3. Cauda Longa (Últimos 20%)'
        END AS faixa_pareto
    FROM devedores_ranqueados
),
resumo_faixas AS (
    SELECT
        faixa_pareto,
        MIN(ranking) AS rank_inicial,
        MAX(ranking) AS rank_final,
        COUNT(*) AS total_devedores,
        ROUND(SUM(valor_divida_selecionada), 2) AS montante_fgts,
        ROUND(AVG(valor_divida_selecionada), 2) AS ticket_medio_fgts,
        ROUND(MEDIAN(valor_divida_selecionada), 2) AS mediana_fgts
    FROM classificacao_pareto
    GROUP BY faixa_pareto
)
SELECT
    faixa_pareto,
    rank_inicial,
    rank_final,
    total_devedores,
    ROUND((total_devedores * 100.0) / SUM(total_devedores) OVER (), 2) AS pct_devedores,
    montante_fgts,
    ROUND((montante_fgts * 100.0) / SUM(montante_fgts) OVER (), 2) AS pct_montante_fgts,
    ticket_medio_fgts,
    mediana_fgts
FROM resumo_faixas
ORDER BY faixa_pareto ASC;

/*
=======================================================================================================================================
-- Query Results & Execution Diagnostics:
- Concentration Tier Breakdown:
  1. Top 50% (Hyper-Concentrated): Rank 01 to 10   |  10 debtors ( 0.96%) | FGTS: R$ 143.53M (49.41%) | Mean: R$ 14.35M | Median: R$ 9.10M
  2. Pareto Core (50% to 80%):    Rank 11 to 77   |  67 debtors ( 6.44%) | FGTS: R$  88.59M (30.50%) | Mean: R$  1.32M | Median: R$ 914.0K
  3. Long Tail (Final 20%):       Rank 78 to 1,041| 964 debtors (92.60%) | FGTS: R$  58.37M (20.09%) | Mean: R$  60.5K  | Median: R$  23.7K

- Critical Pareto Benchmarks:
  * 50% Concentration: Attained by only 10 taxpayers (0.96% of total population).
  * 80% Concentration: Attained by 77 taxpayers (7.40% of total population).
  * Long Tail: 92.60% of all debtors account for merely 20.09% of the outstanding liabilities.

- Strategic Collection Recommendations (PGFN):
  1. Operational Prioritization:
     Target high-impact recovery tools (fiscal precautionary measures, corporate liability 
     redirection to partners, and piercing the corporate veil) strictly at the Top 77 debtors.
  2. Mass-Scale Collection Automation:
     For the 964 debtors in the Long Tail (median debt of R$ 23.7K), formal individual judicial 
     foreclosures incur legal and court processing costs higher than the expected recovery value; 
     the optimal enforcement strategy relies on automated out-of-court notices, credit bureau 
     protests, and standard debt-settlement agreements via the REGULARIZE platform.
=======================================================================================================================================
*/