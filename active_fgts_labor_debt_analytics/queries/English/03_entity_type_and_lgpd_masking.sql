/*
queries/03_entity_type_and_lgpd_masking.sql
====================================================================================================================================
Business Questions:
What is the distribution of active FGTS debt in Ceará between Legal Entities (PJ) and Natural Persons (PF)?
Which debtor class accounts for the largest financial liability, and how do average ticket sizes compare across these employer profiles?

Applied Technical Concepts:
- Regular Expressions: REGEXP_REPLACE to isolate purely numeric digits from document strings
- Conditional Logic: CASE WHEN evaluating document length (factoring in LGPD masking rules)
- Chained CTEs: Modular separation between row-level classification, aggregation, and share computation
- Window Functions: SUM(...) OVER () in the final SELECT to dynamically compute portfolio percentages
====================================================================================================================================
*/

WITH base_classificada AS (
    SELECT
        cpf_cnpj,
        nome_devedor,
        valor_divida_selecionada,
        valor_total,
        CASE 
            -- CNPJ completo (14 dígitos)
            WHEN LENGTH(REGEXP_REPLACE(cpf_cnpj, '[^0-9]', '', 'g')) = 14 
                THEN 'Pessoa Jurídica'
            
            -- CPF sob anonimização da LGPD (6 dígitos centrais preservados com máscara)
            WHEN LENGTH(REGEXP_REPLACE(cpf_cnpj, '[^0-9]', '', 'g')) = 6 AND cpf_cnpj LIKE '%*%' 
                THEN 'Pessoa Física'
            
            -- CPF nominal não mascarado (11 dígitos)
            WHEN LENGTH(REGEXP_REPLACE(cpf_cnpj, '[^0-9]', '', 'g')) = 11 
                THEN 'Pessoa Física'
            
            ELSE 'Documento Inválido / Outro'
        END AS tipo_pessoa
    FROM stg_divida_fgts
),
metricas_agrupadas AS (
    SELECT
        tipo_pessoa,
        COUNT(*)                                            AS total_devedores,
        ROUND(SUM(valor_divida_selecionada), 2)             AS montante_fgts,
        ROUND(AVG(valor_divida_selecionada), 2)             AS ticket_medio_fgts,
        ROUND(MEDIAN(valor_divida_selecionada), 2)          AS mediana_fgts,
        ROUND(MAX(valor_divida_selecionada), 2)             AS maior_divida_fgts
    FROM base_classificada
    GROUP BY tipo_pessoa
)
SELECT
    tipo_pessoa,
    total_devedores,
    ROUND(
        (total_devedores * 100.0) / SUM(total_devedores) OVER (), 2
    )                                                       AS pct_devedores,
    montante_fgts,
    ROUND(
        (montante_fgts * 100.0) / SUM(montante_fgts) OVER (), 2
    )                                                       AS pct_montante_fgts,
    ticket_medio_fgts,
    mediana_fgts,
    maior_divida_fgts
FROM metricas_agrupadas
ORDER BY montante_fgts DESC;

/*
======================================================================================================================================================================
-- Query Results & Execution Diagnostics:
- Volumetrics & Aggregate Capital Exposure:
  * Legal Entities / Corporations (14 digits): 1,013 debtors (97.31%) | R$ 289,796,111.98 (99.76%)
  * Natural Persons / Individuals (6 digits / LGPD): 28 debtors ( 2.69%) | R$     688,437.31 ( 0.24%)
  * Invalid Documents / Other:                          0 debtors ( 0.00%) | R$           0.00 ( 0.00%)

- Measures of Central Tendency & Dispersion:
  * Legal Entities (PJ) - Mean Debt: R$ 286,077.11 | Median: R$ 31,055.81 | Max: R$ 30.38M
  * Natural Persons (PF) - Mean Debt: R$  24,587.05 | Median: R$  6,025.65 | Max: R$ 146.2K

- Analytical Takeaways & Engineering Insights:
A detailed audit via REGEXP_REPLACE revealed that the 6-digit records stem directly from CPF 
anonymization masks applied by PGFN in compliance with Brazilian data privacy regulations (LGPD: ***.XXX.XXX-**).
Delinquent FGTS debt in Ceará is 99.76% corporate (PJ). Natural persons account for a marginal 2.69% 
of debtors with a negligible median liability of R$ 6,025.65, although the single largest individual 
taxpayer has evaded R$ 146,210.46 in mandatory employee labor deposits.
======================================================================================================================================================================
*/