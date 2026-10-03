/*
queries/06_setor_publico_vs_privado.sql
======================================================================================================================================================
Pergunta de Negócio:
Quanto da dívida ativa do FGTS no Ceará pertence a entes da Administração Pública (Prefeituras, Autarquias, Câmaras Municipais e Consórcios Públicos)?
Como o ticket médio e a mediana do setor público se comparam à iniciativa privada?

-- Conceitos aplicados:
- Casamento Semântico de Texto: ILIKE encadeado com termos da administração pública
- Agrupamento e Segmentação Institucional: CASE WHEN gerando 'Administração Pública'
- CTEs Modulares para isolamento de lógica e agregações
- Window Functions para cômputo dinâmico de market share de inadimplência
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
-- Resposta:
- Volumetria & Representatividade de Valor:
  * Iniciativa Privada / Outros: 1.035 devedores (99,42%) | R$ 274.230.140,12 (94,40%) | Dívida Total: R$ 7,92 bi
  * Administração Pública:           6 devedores ( 0,58%) | R$  16.254.409,17 ( 5,60%) | Dívida Total: R$ 454,26 mi

- Comparativo de Dispersão e Concentração Financeira:
  * Privado: Ticket Médio: R$   264.956,66 | Mediana: R$    28.801,06 | Maior Dívida: R$ 30,38M
  * Público: Ticket Médio: R$ 2.709.068,20 | Mediana: R$ 1.537.625,84 | Maior Dívida: R$  8,29M

- Conclusões Analíticas & Relevância de Negócio:
  1. Efeito Alavanca Institucional:
     Apenas 6 entidades públicas respondem por mais de 5% de todo o calote de FGTS do 
     Estado do Ceará, com uma mediana de passivo 53 vezes superior à do setor privado.
  2. Risco de Insolvência vs. Cobrança Especial:
     Diferente de empresas privadas (sujeitas à falência e recuperação judicial), entes 
     públicos não falem, mas suas dívidas são cobradas via precatórios ou retenções do 
     Fundo de Participação dos Municípios (FPM), representando um desafio de execução 
     orçamentária governamental peculiar.
===================================================================================================================
*/