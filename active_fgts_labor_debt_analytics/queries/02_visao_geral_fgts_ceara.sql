/*
queries/02_visao_geral_fgts_ceara.sql
===========================================================================================================
Pergunta de Negócio:
Qual é a volumetria total e o montante consolidado do calote de FGTS no Ceará?
Qual é o comportamento da distribuição desse passivo (Média vs. Mediana)?
Quanto o FGTS representa em relação à dívida total desses contribuintes inscritos na Dívida Ativa da União?

-- Conceitos aplicados:
- Agregações Numéricas: COUNT, COUNT DISTINCT, SUM, MIN, MAX
- Estatística Descritiva: AVG, MEDIAN, STDDEV_SAMP (DuckDB native)
- Cálculos Derivados e Proporções com ROUND
===========================================================================================================
*/

SELECT
-- Volumetria de registros e devedores
COUNT (*) AS total_registros,
COUNT (DISTINCT cpf_cnpj) AS devedores_unicos,

--Montantes financeiros totais
ROUND(SUM(valor_divida_selecionada), 2) AS montante_total_fgts,
ROUND(SUM(valor_total), 2) AS montante_divida_total_uniao,

--Representatividade do FGTS frente ao passivo total com a União (%)
ROUND(
	(SUM(valor_divida_selecionada) / SUM(valor_total)) * 100, 2
) AS pct_fgts_sobre_total,

-- Medidas de Tendência Central (Média vs. Mediana)
ROUND(AVG(valor_divida_selecionada), 2) AS ticket_medio_fgts,
ROUND(MEDIAN(valor_divida_selecionada), 2) AS mediana_fgts,

-- Medidas de Dispersão e Limites
ROUND(MIN(valor_divida_selecionada), 2) AS menor_divida_fgts,
ROUND(MAX(valor_divida_selecionada), 2) AS maior_divida_fgts,
ROUND(STDDEV_SAMP(valor_divida_selecionada), 2) AS desvio_padrao_fgts
FROM stg_divida_fgts;

/*
====================================================================================================================================================
-- Resposta:
- Volumetria:
  * Total de Registros: 1.041
  * Contribuintes Únicos: 1.041 (Integridade de 1:1 confirmada com a Query 01)

- Dimensão Financeira:
  * Montante Total FGTS: R$ 290.484.549,29 (~R$ 290,5 milhões)
  * Passivo Total com a União: R$ 8.374.951.636,51 (~R$ 8,37 bilhões)
  * Representatividade do FGTS: 3,47% da dívida total desses contribuintes

- Dispersão e Assimetria:
  * Menor Dívida FGTS: R$ 12,75 (Débito residual administrativo)
  * Maior Dívida FGTS: R$ 30.384.575,14 (Concentração severa no topo)
  * Ticket Médio: R$ 279.043,76
  * Mediana: R$ 28.896,98
  * Desvio-Padrão Amostral: R$ 1.719.392,31 (Coeficiente de Variação > 600%)

- Conclusão Analítica de Negócio:
  A distribuição do passivo é fortemente assimétrica à direita. A média é severamente distorcida por outliers bilionários/milionários.
  A mediana de R$ 28,9 mil reflete com maior precisão o devedor típico. Além disso, o FGTS representa apenas 3,47% da dívida consolidada com a União,
  apontando que o inadimplemento trabalhista decorre de insolvência fiscal sistêmica.
=====================================================================================================================================================
*/