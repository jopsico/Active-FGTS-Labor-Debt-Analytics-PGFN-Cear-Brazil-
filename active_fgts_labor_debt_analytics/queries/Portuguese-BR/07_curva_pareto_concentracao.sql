/*
queries/07_curva_pareto_concentracao.sql
=========================================================================================================
-- Pergunta de Negócio:
Qual é o grau de concentração da dívida de FGTS no Ceará segundo o Princípio de Pareto?
Quantos devedores do topo (ranking absoluto) acumulam 50% e 80% de todo o montante?
Como se caracterizam a faixa hiperconcentrada e a cauda longa de inadimplentes?

-- Conceitos aplicados:
- Window Frames Analíticos: SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
- Ranking Determinístico: ROW_NUMBER() para ordenação estrita por volume financeiro
- Curva Acumulada: Cálculo dinâmico do percentual cumulativo sobre o montante global
- Bucketing de Pareto: Classificação condicional em faixas de corte executivo
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
-- Resposta:
- Estrutura das Faixas de Concentração:
  1. Top 50% (Hiperconcentrado):  Rank 01 a 10  |  10 devedores ( 0,96%) | FGTS: R$ 143,53M (49,41%) | Méd: R$ 14,35M | Med: R$ 9,10M
  2. Pareto Core (50% a 80%):    Rank 11 a 77  |  67 devedores ( 6,44%) | FGTS: R$  88,59M (30,50%) | Méd: R$  1,32M | Med: R$ 914,0K
  3. Cauda Longa (Últimos 20%):   Rank 78 a 1041| 964 devedores (92,60%) | FGTS: R$  58,37M (20,09%) | Méd: R$  60,5K  | Med: R$  23,7K

- Métricas Críticas de Pareto:
  * Concentração 50%: Alcançada em apenas 10 contribuintes (0,96% da população).
  * Concentração 80%: Alcançada em 77 contribuintes (7,40% da população).
  * Cauda Longa: 92,60% dos devedores respondem por apenas 20,09% do passivo.

- Recomendações Estratégicas para Arrecadação (PGFN):
  1. Focalização Operacional:
     Priorização de medidas cautelares fiscais, redirecionamento para sócios e 
     desconsideração da personalidade jurídica focadas exclusivamente no Top 77.
  2. Automação da Cobrança de Massa:
     Para os 964 devedores da Cauda Longa (mediana de R$ 23,7k), execuções fiscais 
     individuais têm custo de tramitação superior à probabilidade de recuperação; 
     o tratamento ideal exige cobrança extrajudicial automatizada e adesão a transações 
     por adesão no portal REGULARIZE.
=======================================================================================================================================
*/