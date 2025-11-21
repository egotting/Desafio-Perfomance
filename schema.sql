CREATE TABLE clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255),
    cidade VARCHAR(255)
);
CREATE TABLE vendas (
    id SERIAL PRIMARY KEY,
    data_venda DATE NOT NULL,
    loja_id INT NOT NULL,
    valor_total DECIMAL(10,2),
    cliente_id INT REFERENCES clientes(id),
    status VARCHAR(20)
);
-- Inserindo 100 mil clientes
INSERT INTO clientes (nome, cidade)
SELECT
    'Cliente ' || g,
    CASE
        WHEN random() < 0.33 THEN 'São Paulo'
        WHEN random() < 0.66 THEN 'Curitiba'
        ELSE 'Porto Alegre'
    END
FROM generate_series(1, 100000) g;

-- Inserindo 100 mil vendas
INSERT INTO vendas (data_venda, loja_id, valor_total, cliente_id, status)
SELECT
    (NOW() - make_interval(days => (random() * 365)::INT)),  -- 👈 corrigido
    (1 + random() * 100)::INT,
    (10 + random() * 990)::NUMERIC(10,2),
    (1 + random() * 10000)::INT,
    CASE WHEN random() > 0.85 THEN 'CANCELADA' ELSE 'CONCLUIDA' END
FROM generate_series(1, 100000);

-- consulta lenta
EXPLAIN ANALYZE
SELECT
    c.nome,
    c.cidade,
    (SELECT COUNT(*) FROM vendas v2 WHERE v2.cliente_id = c.id) AS total_vendas,
    SUM(v.valor_total) AS total_faturado
FROM vendas v
JOIN clientes c ON v.cliente_id = c.id
WHERE v.status = 'CONCLUIDA'
GROUP BY c.id, c.nome, c.cidade
ORDER BY total_faturado DESC;

-- consulta otimizada
-- criação de indices, uso de CTE, uso de filtro para data de venda
create index idx_vendas_filtros
on vendas (status, data_venda, cliente_id);

EXPLAIN ANALYZE
with vendas_filtradas as (
	select cliente_id, valor_total
	from vendas
	where status = 'CONCLUIDA'
	and data_venda between '2025-01-01' and '2025-12-31'
)

select c.cidade,
	count(vf.cliente_id) as total_vendas,
	sum(vf.valor_total) as total_faturado
FROM vendas_filtradas vf
JOIN clientes c ON vf.cliente_id = c.id
GROUP BY c.cidade
ORDER BY total_faturado DESC;

-- resultado:
--- antes:
---- Planning Time: 345.244 ms
---- Execution Time: 454.700 ms
--- Depois:
---- Planning Time: 0.244 ms
---- Execution Time: 67.700 ms
