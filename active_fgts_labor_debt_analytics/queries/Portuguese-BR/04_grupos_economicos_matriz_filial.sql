/*
queries/04_grupos_economicos_matriz_filial.sql
=======================================================================================================================================
Pergunta de Negócio:
Quais grupos empresariais (mesmo CNPJ Raiz) concentram múltiplos estabelecimentos (matriz e filiais) inadimplentes com o FGTS no Ceará?
Qual é o rombo consolidado por conglomerado econômico?

-- Conceitos aplicados:
- Expressões de String e Regex: REGEXP_REPLACE + SUBSTR para isolar o CNPJ Raiz (8 dígitos)
- Fatiamento de Atributo: Detecção de Matriz (/0001) vs. Filial (/0002+) via SUBSTR
- Agregação com Restrição: GROUP BY com HAVING COUNT(*) > 1
- Métricas Financeiras Consolidadas: SUM, AVG e contagem de unidades afetadas
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
-- Resposta:
- Volumetria de Grupos:
  * Total de Grupos com Múltiplas Unidades: 7 grupos (14 estabelecimentos no total).
  * Estrutura Predominante: 6 grupos com 1 Matriz (/0001) e 1 Filial (/0002+).
  * Anomalia Cadastral Local: 1 grupo (Laboratório Color Esdras) com 2 filiais 
    e 0 matrizes inscritas no Ceará.

- Ranking dos Maiores Montantes de FGTS:
  1. UNITEXTIL S/A:                    R$ 5.218.299,64 (2 unidades | Méd: R$ 2,60M)
  2. SANTA CASA DE MISERICÓRDIA:       R$ 2.372.461,48 (2 unidades | Méd: R$ 1,18M)
  3. KM BRASIL LTDA:                   R$   704.088,33 (2 unidades | Méd: R$ 352,0K)
  4. LAM CONFECCOES SA:                R$   624.153,54 (2 unidades | Méd: R$ 312,0K)
  5. ANGELO FIGUEIREDO S/A (ANFISA):   R$   110.367,47 (2 unidades | Méd: R$  55,1K)
  6. FAZENDA BOM AGROCOMERCIAL LTDA:   R$    49.963,25 (2 unidades | Méd: R$  24,9K)
  7. LABORATORIO COLOR ESDRAS LTDA:    R$    24.450,08 (2 filiais  | Méd: R$  12,2K)

- Conclusão Analítica de Negócio:
  A pulverização por filiais é residual na base cearense do FGTS (menos de 2% dos contribuintes PJ). Nota-se uma dualidade de comportamento devedor:
  entidades cujo passivo federal é estritamente trabalhista (Unitêxtil e Santa Casa com ~100% em FGTS) versus conglomerados industriais/agropecuários em crise fiscal ampla, 
  onde o passivo trabalhista representa uma fatia irrisória da dívida perante a União.
=============================================================================================================================================================================
*/