/*
queries/06_public_vs_private_sector.sql
======================================================================================================================================================
Business Questions:
How much of Ceará's active FGTS labor debt belongs to Public Administration entities (Municipal City Halls, Autonomous Agencies, City Councils, and Public Consortia)?
How do the mean and median debt metrics of the public sector compare against the private sector?

Applied Technical Concepts:
- Semantic Text Pattern Matching: Chained ILIKE filters targeting public administration terminology
- Institutional Grouping & Categorization: CASE WHEN generating 'Public Administration' vs. 'Private Sector / Other'
- Modular CTEs: Architectural isolation between classification logic and metric aggregations
- Window Functions: Dynamic market share computation across debtor counts and outstanding capital
======================================================================================================================================================
*/

WITH base_classificada AS (
    SELECT
        cpf_cnpj,
        nome_devedor,
        nome_fantasia,
        valor_divida_selecionada,
        valor_total,
        CASE
            WHEN nome_devedor ILIKE '%MUNICIPIO%'
              OR nome_devedor ILIKE '%PREFEITURA%'
              OR nome_devedor ILIKE '%AUTARQUIA%'
              OR nome_devedor ILIKE '%CAMARA MUNICIPAL%'
              OR nome_devedor ILIKE '%CONSORCIO PUBLICO%'
              OR nome_devedor ILIKE '%CONSORCIO INTERMUNICIPAL%'
              OR nome_devedor ILIKE '%SECRETARIA%'
              OR nome_devedor ILIKE '%ESTADO DO CEARA%'
              OR nome_devedor ILIKE '%SERVICO AUTONOMO DE AGUA%'
              OR nome_devedor ILIKE '%SAAE%'
              OR nome_fantasia ILIKE '%PREFEITURA%'
              OR nome_fantasia ILIKE '%URBFOR%'
            THEN 'Administração Pública'
            ELSE 'Iniciativa Privada / Outros'
        END AS esfera_institucional
    FROM stg_divida_fgts
),
metricas_setor AS (
    SELECT
        esfera_institucional,
        COUNT(*) AS total_devedores,
        ROUND(SUM(valor_divida_selecionada), 2) AS montante_fgts,
        ROUND(SUM(valor_total), 2) AS montante_uniao,
        ROUND(AVG(valor_divida_selecionada), 2) AS ticket_medio_fgts,
        ROUND(MEDIAN(valor_divida_selecionada), 2) AS mediana_fgts,
        ROUND(MAX(valor_divida_selecionada), 2) AS maior_divida_fgts
    FROM base_classificada
    GROUP BY esfera_institucional
)
SELECT
    esfera_institucional,
    total_devedores,
    ROUND((total_devedores * 100.0) / SUM(total_devedores) OVER (), 2) AS pct_devedores,
    montante_fgts,
    ROUND((montante_fgts * 100.0) / SUM(montante_fgts) OVER (), 2) AS pct_montante_fgts,
    montante_uniao,
    ticket_medio_fgts,
    mediana_fgts,
    maior_divida_fgts
FROM metricas_setor
ORDER BY montante_fgts DESC;

/*
===================================================================================================================
-- Query Results & Execution Diagnostics:
- Volumetrics & Capital Exposure:
  * Private Sector / Other:      1,035 debtors (99.42%) | R$ 274,230,140.12 (94.40%) | Consolidated Federal: R$ 7.92B
  * Public Administration:           6 debtors ( 0.58%) | R$  16,254,409.17 ( 5.60%) | Consolidated Federal: R$ 454.26M

- Measures of Dispersion & Financial Skewness:
  * Private Sector: Mean Debt: R$   264,956.66 | Median: R$    28,801.06 | Max Debt: R$ 30.38M
  * Public Sector:  Mean Debt: R$ 2,709,068.20 | Median: R$ 1,537,625.84 | Max Debt: R$  8.29M

- Analytical Findings & Strategic Business Takeaways:
  1. Institutional Leverage Effect:
     Only 6 public sector entities account for over 5.60% of Ceará's entire active FGTS 
     debt, exhibiting a median liability 53 times higher than that of the private sector.
  2. Insolvency Dynamics vs. Specialized Enforcement:
     Unlike private corporations (which are subject to judicial recovery and bankruptcy liquidation), 
     public administrative bodies cannot enter bankruptcy; instead, their debts are enforced 
     via court-ordered debt payments (precatórios) or direct withholdings from the Municipal 
     Revenue Sharing Fund (Fundo de Participação dos Municípios - FPM), requiring specialized 
     inter-governmental collection strategies.
===================================================================================================================
*/