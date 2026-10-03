/*
queries/01_auditoria_qualidade_duplicidade.sql
==============================================================================================================================
Pergunta de Negócio:
A chave natural 'cpf_cnpj' é estritamente única na extração da PGFN ou existem registros duplicados para o mesmo contribuinte?
Se existirem duplicatas, como priorizar e isolar o registro de maior impacto?

-- Conceitos aplicados:
- Common Table Expression (CTE) para estruturação modular
- Window Function: ROW_NUMBER() com PARTITION BY e ORDER BY
- Padrão de Deduplicação canônica em Data Warehouses
===============================================================================================================================
*/

WITH ranked_devedores AS (
SELECT
	cpf_cnpj,
	nome_devedor,
	nome_fantasia,
	valor_total,
	valor_divida_selecionada,
	ROW_NUMBER() OVER (
		PARTITION BY cpf_cnpj
		ORDER BY valor_divida_selecionada DESC, valor_total DESC
			) AS rn
		FROM stg_divida_fgts
	)
SELECT
	cpf_cnpj,
	nome_devedor,
	nome_fantasia,
	valor_total,
	valor_divida_selecionada,
	rn AS indice_duplicidade
FROM ranked_devedores
WHERE rn > 1
ORDER BY valor_divida_selecionada DESC;

/*
=================================================================================================================================================
-- Resposta: Retorno da consulta: 0 linhas. A chave primária natural 'cpf_cnpj' é estritamente única no dataset exportado.
O extrator oficial da PGFN já entrega os débitos previamente consolidados por contribuinte, confirmando a granularidade de 1 linha por documento.

-- Impacto para o Pipeline:
  1. Inexistência de risco de 'double counting' (dupla contagem) em métricas
     financeiras agregadas (SUM, AVG) nas consultas seguintes.
  2. Dispensa a necessidade de filtros ou rotinas adicionais de deduplicação
     nas camadas analíticas a jusante (downstream).
==================================================================================================================================================
*/