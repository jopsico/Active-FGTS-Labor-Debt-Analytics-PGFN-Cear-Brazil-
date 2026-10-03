/*
queries/05_participacao_fgts_na_divida_uniao.sql
============================================================================================================
-- Pergunta de Negócio:
Qual é o grau de representatividade do FGTS frente ao passivo total com a União?
Quantos contribuintes possuem passivo exclusivamente trabalhista (100% FGTS) versus 
quantos utilizam a retenção do FGTS como financiamento em meio a uma inadimplência fiscal sistêmica (< 10%)?

-- Conceitos aplicados:
- Proteção Numérica: NULLIF(valor_total, 0) contra divisão por zero
- Categorização em Faixas (Bucketing): CASE WHEN com ranges percentuais
- CTEs Modulares: Separação entre cálculo de share, agrupamento e shares relativos
- Window Functions: SUM(...) OVER () para distribuição percentual de devedores e valores
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
-- Resposta:
- Distribuição por Perfil de Inadimplência:
  1. Exclusivo FGTS (100%):       357 devedores (34,29%) | FGTS: R$  40,64M (13,99%) | União: R$   40,64M | Mediana: R$  9,5K
  2. Majoritário (50% a 99%):      97 devedores ( 9,32%) | FGTS: R$  14,31M ( 4,93%) | União: R$   18,00M | Mediana: R$ 55,5K
  3. Relevante (10% a 49%):       182 devedores (17,48%) | FGTS: R$  93,10M (32,05%) | União: R$  451,64M | Mediana: R$ 65,5K
  4. Residual / Sistêmico (<10%): 405 devedores (38,90%) | FGTS: R$ 142,43M (49,03%) | União: R$ 7.864,67M | Mediana: R$ 28,5K

- Insights de Negócio & Estratégia de Cobrança:
  * Bipolaridade Crítica:
    - 34,29% dos devedores têm pendências estritamente de FGTS (passivo isolado).
    - Quase metade do valor do FGTS (49,03%) está aprisionada no grupo 'Residual / Sistêmico',
      onde os devedores acumulam R$ 7,86 bilhões em dívidas tributárias federais.
  * Inteligência de Recuperação de Crédito:
    - Cobranças amigáveis e editais de transação tributária específica de FGTS têm 
      alta viabilidade de conversão no Grupo 1 (mediana de R$ 9,5k sem passivo tributário concorrente).
    - No Grupo 4, ações individuais de cobrança de FGTS possuem baixa efetividade 
      sem ajuizamento coordenado de execuções fiscais e redirecionamento societário, dada a insolvência ampla.
===============================================================================================================================
*/