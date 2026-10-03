/*
queries/04_corporate_groups_parent_branch.sql
=======================================================================================================================================
Business Questions:
Which corporate groups (sharing the same 8-digit root CNPJ) hold multiple delinquent establishments (headquarters vs. branches) in Ceará?
What is the total consolidated liability per corporate conglomerate?

Applied Technical Concepts:
- String Manipulation & Regular Expressions: REGEXP_REPLACE + SUBSTR to extract the 8-digit root CNPJ
- Substring Attribute Slicing: Distinguishing Headquarters (/0001) vs. Branches (/0002+) via SUBSTR
- Constrained Aggregation: GROUP BY paired with HAVING COUNT(*) > 1 to isolate multi-unit debtors
- Consolidated Financial Metrics: SUM, AVG, and establishment-level counts
=======================================================================================================================================
*/
WITH pj_higienizada AS (
    SELECT
        cpf_cnpj,
        REGEXP_REPLACE(cpf_cnpj, '[^0-9]', '', 'g') AS cnpj_digitos,
        nome_devedor,
        nome_fantasia,
        valor_divida_selecionada,
        valor_total
    FROM stg_divida_fgts
    WHERE LENGTH(REGEXP_REPLACE(cpf_cnpj, '[^0-9]', '', 'g')) = 14
),
grupos_consolidados AS (
    SELECT
        SUBSTR(cnpj_digitos, 1, 8)                                             AS cnpj_raiz,
        -- Retorna o nome corporativo mais representativo para visualização
        MAX(nome_devedor)                                                      AS razao_social_referencia,
        COUNT(*)                                                               AS total_estabelecimentos,
        -- Mapeia a presença de débitos na Matriz (/0001) e nas Filiais (/0002+)
        SUM(CASE WHEN SUBSTR(cnpj_digitos, 9, 4) = '0001' THEN 1 ELSE 0 END)  AS qtd_matrizes_inscritas,
        SUM(CASE WHEN SUBSTR(cnpj_digitos, 9, 4) != '0001' THEN 1 ELSE 0 END) AS qtd_filiais_inscritas,
        ROUND(SUM(valor_divida_selecionada), 2)                                AS montante_fgts_grupo,
        ROUND(SUM(valor_total), 2)                                             AS montante_uniao_grupo,
        ROUND(AVG(valor_divida_selecionada), 2)                                AS ticket_medio_por_unidade
    FROM pj_higienizada
    GROUP BY SUBSTR(cnpj_digitos, 1, 8)
    HAVING COUNT(*) > 1
)
SELECT
    cnpj_raiz,
    razao_social_referencia,
    total_estabelecimentos,
    qtd_matrizes_inscritas,
    qtd_filiais_inscritas,
    montante_fgts_grupo,
    montante_uniao_grupo,
    ticket_medio_por_unidade
FROM grupos_consolidados
ORDER BY montante_fgts_grupo DESC;

/*
=============================================================================================================================================================================
-- Query Results & Execution Diagnostics:
- Corporate Group Volumetrics:
  * Total Multi-Establishment Groups: 7 corporate groups (14 total establishments).
  * Predominant Structure: 6 groups with 1 Headquarters (/0001) and 1 Branch (/0002+).
  * Local Operational Anomaly: 1 group (Laboratório Color Esdras) with 2 active branches 
    and 0 headquarters registered in Ceará.

- Top Consolidated FGTS Debt by Conglomerate:
  1. UNITEXTIL S/A:                    R$ 5,218,299.64 (2 establishments | Avg: R$ 2.60M)
  2. SANTA CASA DE MISERICÓRDIA:       R$ 2,372,461.48 (2 establishments | Avg: R$ 1.18M)
  3. KM BRASIL LTDA:                   R$   704,088.33 (2 establishments | Avg: R$ 352.0K)
  4. LAM CONFECCOES SA:                R$   624,153.54 (2 establishments | Avg: R$ 312.0K)
  5. ANGELO FIGUEIREDO S/A (ANFISA):   R$   110,367.47 (2 establishments | Avg: R$  55.1K)
  6. FAZENDA BOM AGROCOMERCIAL LTDA:   R$    49,963.25 (2 establishments | Avg: R$  24.9K)
  7. LABORATORIO COLOR ESDRAS LTDA:    R$    24,450.08 (2 branches       | Avg: R$  12.2K)

- Analytical & Business Takeaways:
  Branch fragmentation is marginal within Ceará's active FGTS debtor base (under 2% of corporate taxpayers). 
  A sharp behavioral divergence emerges between conglomerates: entities whose federal liabilities are strictly 
  labor-related (Unitêxtil and Santa Casa with ~100% in FGTS) versus industrial and agribusiness conglomerates 
  under broad fiscal insolvency, where labor liabilities represent only an insignificant fraction of their total federal debt.
=============================================================================================================================================================================
*/