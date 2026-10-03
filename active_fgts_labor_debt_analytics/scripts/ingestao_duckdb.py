import duckdb

con = duckdb.connect('pgfn_ceara.duckdb')

con.execute("""
    CREATE OR REPLACE TABLE divida_fgts AS
    SELECT *
    FROM read_csv_auto(
        'Consulta_Lista_Devedores_2026_10_02.csv',
        header=True,
        delim=';',
        encoding='latin-1'
    );
""")

total = con.execute('SELECT COUNT(*) FROM divida_fgts').fetchone()[0]
print(f'Base criada com sucesso! Total de registros: {total}')

print("\nSchema detectado:")
schema = con.execute("DESCRIBE divida_fgts;").df()
print(schema[['column_name', 'column_type']])

con.close()