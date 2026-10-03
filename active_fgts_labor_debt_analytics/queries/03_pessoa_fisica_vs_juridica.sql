/*
queries/03_pessoa_fisica_vs_juridica.sql
====================================================================================================================================
Pergunta de Negócio:
Qual é a distribuição da dívida de FGTS no Ceará entre Pessoa Jurídica (PJ) e Pessoa Física (PF)?
Qual classe responde pelo maior montante financeiro e como os tickets médios se comparam entre essas duas naturezas de empregadores?

Conceitos aplicados:
- Expressões Regulares: REGEXP_REPLACE para extração exclusiva de dígitos numéricos
- Estrutura Condicional: CASE WHEN avaliando o tamanho do documento (11 vs 14)
- CTEs encadeadas: Separação entre classificação, agregação e cálculo de share
- Window Functions no SELECT final: SUM(...) OVER () para percentual sobre o total
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
-- Resposta:
- Volumetria & Montante:
  * Pessoa Jurídica (14 dígitos): 1.013 devedores (97,31%) | R$ 289.796.111,98 (99,76%)
  * Pessoa Física (6 dígitos / LGPD): 28 devedores (2,69%)  | R$ 688.437,31 (0,24%)
  * Documentos Inválidos / Outros:     0 devedores (0,00%)  | R$ 0,00 (0,00%)

- Métricas de Tendência Central:
  * PJ - Ticket Médio: R$ 286.077,11 | Mediana: R$ 31.055,81 | Máximo: R$ 30,38M
  * PF - Ticket Médio: R$ 24.587,05  | Mediana: R$ 6.025,65  | Máximo: R$ 146,2K

- Conclusão Analítica & Valor de Engenharia:
A auditoria detalhada via REGEXP_REPLACE identificou que os registos de 6 dígitos decorrem da anonimização de CPFs pela PGFN em cumprimento da LGPD (***.XXX.XXX-**).
A dívida do FGTS no Ceará é 99,76% corporativa (PJ). As Pessoas Físicas (2,69% da base) possuem um passivo residual com mediana de apenas R$ 6.025,65
embora o maior devedor individual atinja R$ 146.210,46 de encargos trabalhistas sonegados.
======================================================================================================================================================================
*/