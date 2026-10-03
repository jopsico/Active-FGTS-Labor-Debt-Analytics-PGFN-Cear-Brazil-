/*
-- queries/00_staging_divida_fgts.sql
===================================================================================================================
Camada: Staging (Silver Layer / ELT)
Objetivo:
Padronizar e higienizar a base bruta de devedores do FGTS (PGFN - Ceará).
Normaliza nomes de colunas para snake_case, trata espaços residuais, 
converte ausência de dados em NULL canônico e faz o parsing de moeda BRL para tipos numéricos exatos de ponto fixo.

Conceitos e Decisões Técnicas:
- Abordagem ELT: Carga bruta preservada; transformações versionadas em SQL
- Funções de String: TRIM e NULLIF para integridade cadastral
- Tipagem Financeira: REPLACE encadeado + TRY_CAST para DECIMAL(18, 2)
===================================================================================================================
*/

CREATE OR REPLACE VIEW stg_divida_fgts AS
SELECT
    TRIM("CPF/CNPJ") AS cpf_cnpj,
    TRIM("Nome") AS nome_devedor,
    NULLIF(TRIM("Nome Fantasia"), '') AS nome_fantasia,
    TRY_CAST(REPLACE(REPLACE(TRIM("Valor Total"), '.', ''), ',', '.') AS DECIMAL(18, 2)) AS valor_total,
    TRY_CAST(REPLACE(REPLACE(TRIM("Valor da Dívida Selecionada"), '.', ''), ',', '.') AS DECIMAL(18, 2)) AS valor_divida_selecionada
FROM divida_fgts;

/*
-- Notas Técnicas e impacto de arquitetura:
============================================================================
1. Separação de Responsabilidades (DRY - Don't Repeat Yourself):
   A criação desta View evita a repetição exaustiva de rotinas de CAST e 
   REPLACE em cada consulta analítica subsequente, centralizando a regra
   de higienização em um único objeto de catálogo.

2. Precisão Financeira (DECIMAL vs. FLOAT):
   A adoção explícita de DECIMAL(18, 2) previne perdas de centavos por erro 
   de ponto flutuante binário em operações de agregação (SUM, AVG).

3. Resiliência do Pipeline (TRY_CAST):
   Diferente do CAST padrão, o TRY_CAST degrada falhas de parsing para NULL 
   sem abortar o processamento analítico caso surjam registros corrompidos.
==============================================================================
*/