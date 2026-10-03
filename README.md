# Active FGTS Labor Debt Analytics (PGFN / Ceará, Brazil)

A production-grade analytical repository utilizing **DuckDB** and **SQL** to perform data quality auditing, declarative ELT modeling, and fiscal intelligence on delinquent Severance Indemnity Fund (**FGTS**) liabilities registered by the Brazilian Federal Attorney General's Office (**PGFN**) in the State of Ceará.

---

## 1. Architecture & Technology Stack

* **OLAP Processing Engine:** [DuckDB](https://duckdb.org/) (high-performance, vectorized in-process columnar SQL database).
* **Database Client:** [DBeaver Community](https://dbeaver.io/) via native DuckDB JDBC driver.
* **Data Modeling Paradigm:** **ELT** (*Extract, Load, Transform*). Raw data is ingested as-is into a raw table (`divida_fgts`), while downstream data hygiene, null-coalescing, and fixed-point currency casting are version-controlled declaratively within an analytical staging view (`stg_divida_fgts`).

### Repository Structure

### Repository Structure

```text
├── .gitignore
├── LICENSE
├── README.md
└── active_fgts_labor_debt_analytics/
    ├── Consulta_Lista_Devedores_2026_10_02.csv  # Raw PGFN official extract (1,041 records)
    ├── scripts/
    │   └── ingestao_duckdb.py                   # Automated Python ingestion & schema initialization
    └── queries/
        ├── English/
        │   ├── 00_staging_fgts_debt.sql         # Declarative ELT view & data contracts
        │   ├── 01_data_quality_pk_uniqueness.sql
        │   ├── 02_macro_metrics_and_skewness.sql
        │   ├── 03_entity_type_and_lgpd_masking.sql
        │   ├── 04_corporate_groups_parent_branch.sql
        │   ├── 05_labor_vs_systemic_tax_insolvency.sql
        │   ├── 06_public_vs_private_sector.sql
        │   └── 07_pareto_concentration_analysis.sql
        └── Portuguese-BR/
            ├── 00_staging_divida_fgts.sql
            ├── 01_auditoria_qualidade_duplicidade.sql
            ├── 02_visao_geral_fgts_ceara.sql
            ├── 03_pessoa_fisica_vs_juridica.sql
            ├── 04_grupos_economicos_matriz_filial.sql
            ├── 05_participacao_fgts_na_divida_uniao.sql
            ├── 06_setor_publico_vs_privado.sql
            └── 07_curva_pareto_concentracao.sql
```

## 2. Staging Layer & Data Contracts (`stg_divida_fgts`)

Raw municipal/state extractions typically suffer from inconsistent string formatting, Brazilian Real (BRL) currency symbols with inverted separators (`.` as thousands, `,` as decimals), trailing whitespace, and blank strings representing missing metadata.

The staging view (`stg_divida_fgts`) enforces the following data contract:

* **Fixed-Point Precision (`DECIMAL(18, 2)`):** Monetary figures are converted using `TRY_CAST(REPLACE(REPLACE(...)))` to eliminate binary floating-point representation errors (`FLOAT`/`DOUBLE`) during downstream aggregation.
* **Canonical Null Handling:** Converts empty text inputs (`''`) into explicit SQL `NULL` values via `NULLIF(TRIM(...), '')`.
* **Fault-Tolerant Casting:** Employs `TRY_CAST` to ensure potential parsing anomalies degrade to `NULL` rather than breaking ETL pipeline execution.

---

## 3. Analytical Findings & Executive Insights

### A. Data Quality Gate: Key Integrity Audit
A primary key audit utilizing `ROW_NUMBER() OVER (PARTITION BY cpf_cnpj ORDER BY valor_divida_selecionada DESC)` returned **0 duplicate rows**. 

This confirms that the PGFN extract operates at a strict **1:1 granularity per taxpayer identifier**, eliminating the risk of double-counting in downstream financial metrics.

---

### B. Descriptive Statistics: The Mean Trap & Extreme Skewness
The total active FGTS labor debt in Ceará stands at **R$ 290.48 million**, nested inside a total federal liability of **R$ 8.37 billion** owed by these exact same contributors (FGTS represents only **3.47%** of their total federal debt).

| Metric | Value (BRL) | Engineering / Analytical Diagnostic |
| :--- | :--- | :--- |
| **Total FGTS Debt** | R$ 290,484,549.29 | Cumulative unremitted labor guarantee funds |
| **Total Federal Debt** | R$ 8,374,951,636.51 | Consolidated tax, social security, and labor liabilities |
| **FGTS Share of Total** | 3.47% | FGTS is largely a secondary symptom of wider insolvency |
| **Mean Debt (Average)** | R$ 279,043.76 | Severely skewed upward by high-value outliers |
| **Median Debt** | R$ 28,896.98 | Robust measure of central tendency for the typical debtor |
| **Minimum Debt** | R$ 12.75 | Administrative residual record below judicial threshold |
| **Maximum Debt** | R$ 30,384,575.14 | Absolute single-debtor peak concentration |
| **Standard Deviation** | R$ 1,719,392.31 | Coefficient of Variation > 600% (extreme dispersion) |

> **Analytical Takeaway:** Relying on the mean debt of R$ 279K introduces significant bias. Half of all delinquent entities owe R$ 28.9K or less. The extreme positive skewness mandates distinct operational strategies for large litigators versus bulk administrative collections.

---

### C. Legal Entity Classification & LGPD De-Masking
Evaluating taxpayer identifier lengths with regular expressions (`REGEXP_REPLACE`) uncovered the distribution of delinquent accounts:

* **Corporations / Legal Entities (14-digit CNPJ):** 1,013 debtors (**97.31%** of total) account for **99.76% of the financial liability** (R$ 289.80 million).
* **Natural Persons / Individuals (6 visible digits):** 28 debtors (**2.69%** of total) account for **0.24% of the debt** (R$ 688.4K, with a median of R$ 6,025.65).
* **Compliance Insight:** The presence of 6-digit documents stems from federal compliance with Brazil's General Data Protection Law (**LGPD**), which applies anonymization masks to individual taxpayers (`***.XXX.XXX-**`).

---

### D. Corporate Group Consolidation (Parent-Branch Slicing)
Extracting the 8-digit CNPJ root (`SUBSTR(cnpj, 1, 8)`) reveals minimal local branch fragmentation: only **7 corporate conglomerates** hold multiple delinquent units in Ceará (each holding exactly 2 registered establishments).

* **Top Delinquent Groups:** `UNITEXTIL S/A` (R$ 5.22 million consolidated) and `SANTA CASA DE MISERICÓRDIA DE FORTALEZA` (R$ 2.37 million consolidated).
* **Operational Anomaly:** `LABORATÓRIO COLOR ESDRAS LTDA` holds 2 active delinquent branches in Ceará while its corporate headquarters (`/0001`) is absent from the state debt roll, indicating either an out-of-state parent company or selective local compliance failure.

---

### E. Insolvency Segmentation: Dedicated Debtors vs. Systemic Default
Segmenting contributors by the proportion of FGTS relative to their total federal debt highlights a sharp structural divide:

1. **Dedicated FGTS Debtors (100% FGTS):** 357 entities (**34.29%** of base) owe zero federal tax liabilities outside of their unremitted FGTS (R$ 40.64 million total, median of **R$ 9,518.66**). These represent viable candidates for targeted administrative recovery programs.
2. **Systemic Fiscal Insolvency (< 10% FGTS):** 405 entities (**38.90%** of base) drive nearly half of the entire state FGTS deficit (**R$ 142.43 million**). These same entities owe **R$ 7.86 billion** to the federal government, proving that unremitted employee FGTS deposits were systematically absorbed as unauthorized operational capital.

---

### F. Public Sector vs. Private Sector Delinquency
Semantic string parsing (`ILIKE`) isolated government bodies, city halls, municipal departments, and public foundations:

* **High-Impact Minority:** Only **6 public sector entities (0.58%)** account for **R$ 16.25 million (5.60%)** of Ceará's active FGTS debt.
* **Median Disparity:** The public sector median debt is **R$ 1.54 million**—over **53 times higher** than the private sector median (R$ 28.8K).
* **Key Cases:** Municipal entities such as `URBFOR` (R$ 8.29 million) and inland city governments display multi-million-real liabilities affecting outsourced and contracted public workers.

---

### G. Pareto Concentration Analysis (The 80 / 7.4 Rule)
Applying analytical window frames (`SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`) demonstrates that debt concentration in Ceará surpasses the classical 80/20 rule:

```text
[=========== Top 10 Debtors (0.96%) ===========]  --> 49.41% of debt (R$ 143.53M)
[====================== Top 77 Debtors (7.40%) ======================]  --> 79.91% of debt (R$ 232.12M)
[----------------------------- Long Tail: 964 Debtors (92.60%) -----------------------------]  --> 20.09% of debt
```

* **Top 10 Ultra-Concentrated Tier:** Less than 1% of entities account for roughly half of all unpaid FGTS in the state (average debt of R$ 14.35 million).
* **The Pareto Core (Rank 11 to 77):** 67 entities account for 30.50% of total debt (average debt of R$ 1.32 million).
* **The Judicial Long Tail (Rank 78 to 1,041):** 964 entities represent **92.60% of all legal cases**, yet account for only **20.09% of the recoverable capital** (median of R$ 23,680.10).

---

## 4. Reproducing the Pipeline

### Prerequisites
* **Python 3.9+** (with `duckdb` library installed)
* **DuckDB CLI** (v0.9.0 or later) or **DBeaver Community** with native DuckDB driver

### Step-by-Step Execution

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/jopsico/pgfn-fgts-debt-analytics.git
   cd active_fgts_labor_debt_analytics
   ```

2. **Run Automated Ingestion (Python Raw Ingestion Layer):**
   Execute the ingestion script to instantiate the local database file and ingest the raw extract:
   ```bash
   cd active_fgts_labor_debt_analytics
   python scripts/ingestao_duckdb.py
   ```
   *This automated pipeline loads `Consulta_Lista_Devedores_2026_10_02.csv` into a persistent DuckDB database file, creating the physical `divida_fgts` raw table.*

3. **Connect via DBeaver or DuckDB CLI:**
   * Open **DBeaver** and create a new **DuckDB** connection.
   * Point the database path directly to the `.duckdb` file generated by the Python script in the previous step.
   * Open an active SQL editor session linked to this connection.

4. **Deploy Staging View (Silver Layer):**
   Execute `queries/English/00_staging_fgts_debt.sql` (or `queries/Portuguese-BR/00_staging_divida_fgts.sql`) to compile the sanitized, strictly typed view (`stg_divida_fgts`).

5. **Execute Analytical & Diagnostic Suite:**
   Run scripts `01` through `07` sequentially against the staging view:
   * `01_data_quality_pk_uniqueness.sql`
   * `02_macro_metrics_and_skewness.sql`
   * `03_entity_type_and_lgpd_masking.sql`
   * `04_corporate_groups_parent_branch.sql`
   * `05_labor_vs_systemic_tax_insolvency.sql`
   * `06_public_vs_private_sector.sql`
   * `07_pareto_concentration_analysis.sql`
