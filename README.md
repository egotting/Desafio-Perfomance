## repositorio: https://github.com/matheuslf/dev.matheuslf.desafio.performance/tree/main

# 🚀 Desafio de Performance – Otimizando Consultas SQL Reais

Imagine que você trabalha num sistema que precisa gerar **relatórios de vendas diárias**.  
Mas o banco de dados tem **mais de 10 milhões de linhas**, e aquela query que **deveria rodar em 200ms** agora está levando **15 segundos**.

Seu chefe chega e diz:  
> 💬 “O cliente tá reclamando, descobre o que tá acontecendo!”

Seu desafio é **descobrir o gargalo de performance** e **otimizar a consulta SQL**.

---

## 🧱 Estrutura das tabelas

```sql
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

```

## Gerando dados simulados

Vamos popular as tabelas com dados realistas para testar performance.

```sql
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
```

## 🐢 Query inicial (lenta)

Essa é a consulta que precisa ser otimizada.
Ela traz o total de vendas por cliente, mas está com plano de execução ineficiente.

```sql
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
```

## 🎯 Objetivo
1- Entender por que a consulta está lenta
2- Usar o EXPLAIN ANALYZE para investigar o plano de execução
3- Identificar Seq Scan, Sort, Nested Loop e tentar substituí-los por estratégias mais eficientes, como:
4- Índices (CREATE INDEX)
5- JOIN otimizados
6- Subqueries substituídas por JOIN ou CTEs
