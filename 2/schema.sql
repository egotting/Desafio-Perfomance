CREATE TABLE rotas (
    id SERIAL PRIMARY KEY,
    origem VARCHAR(50),
    destino VARCHAR(50),
    distancia_km INT
);

CREATE TABLE motoristas (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100),
    categoria_cnh VARCHAR(5)
);

CREATE TABLE entregas (
    id BIGSERIAL PRIMARY KEY,
    rota_id INT NOT NULL REFERENCES rotas(id),
    motorista_id INT NOT NULL REFERENCES motoristas(id),
    status VARCHAR(20),
    horario_saida TIMESTAMP,
    horario_entrega TIMESTAMP,
    peso_kg NUMERIC(10,2),
    valor_frete NUMERIC(10,2)
);

-- 20 mil rotas
INSERT INTO rotas (origem, destino, distancia_km)
SELECT
    'Cidade ' || (random()*100)::int,
    'Cidade ' || (random()*100)::int,
    (random()*900 + 50)::int
FROM generate_series(1, 20000);

-- 50 mil motoristas
INSERT INTO motoristas (nome, categoria_cnh)
SELECT
    'Motorista ' || g,
    (ARRAY['B','C','D','E'])[1 + (random()*3)::int]
FROM generate_series(1, 50000) g;

-- 5 milhões de entregas
INSERT INTO entregas (rota_id, motorista_id, status, horario_saida, horario_entrega, peso_kg, valor_frete)
SELECT
    (random()*19999)::int + 1,
    (random()*49999)::int + 1,
    CASE WHEN random() < 0.1 THEN 'CANCELADA' ELSE 'ENTREGUE' END,
    now() - (random()*interval '20 days'),
    now() - (random()*interval '20 days'),
    (random()*500)::numeric(10,2),
    (random()*300)::numeric(10,2)
FROM generate_series(1, 5000000);


--- QUERY LENTA: 16s

EXPLAIN ANALYZE
SELECT
    r.origem,
    r.destino,
    (SELECT COUNT(*)
     FROM entregas e2
     WHERE e2.rota_id = r.id AND e2.status = 'ENTREGUE') AS total_entregas,
    AVG(e.valor_frete) AS media_frete,
    AVG(EXTRACT(EPOCH FROM (e.horario_entrega - e.horario_saida))/3600) AS horas_medias
FROM entregas e
JOIN rotas r ON r.id = e.rota_id
WHERE e.status = 'ENTREGUE'
GROUP BY r.id, r.origem, r.destino
ORDER BY media_frete DESC
LIMIT 50;



--- QUERY OTIMIZADA 1s
create index idx_entregas
on entregas(status, rota_id, horario_saida, horario_entrega)
include(valor_frete)
where status = 'ENTREGUE';
explain analyze
with filtra_entrega as(
	select e.rota_id, e.status ,e.horario_entrega, e.horario_saida, e.valor_frete
	from entregas e
	where e.status = 'ENTREGUE'
	and e.horario_entrega >= e.horario_saida
	and (e.horario_entrega - e.horario_saida) > interval '0'

)
select
    r.origem,
    r.destino,
    count(ef.rota_id) as total_entregas,
    avg(ef.valor_frete) as media_frete,
    avg(extract(epoch from( ef.horario_entrega - ef.horario_saida))) / 3600 as horas_medias
from filtra_entrega ef
left join rotas r on r.id = ef.rota_id
group by r.origem, r.destino
order by media_frete desc
limit 50;
