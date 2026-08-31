INSERT INTO roles (name, description) VALUES
  ('Administrador', 'Configura o sistema, usuarios e relatorios'),
  ('Gestor', 'Acompanha, aprova e consulta indicadores'),
  ('Responsavel pelo ambiente', 'Preenche checklists dos locais designados'),
  ('Manutencao', 'Recebe, atualiza e encerra ocorrencias'),
  ('Almoxarifado', 'Controla estoque, patrimonio e emprestimos'),
  ('Consulta/Auditoria', 'Visualiza registros e relatorios sem editar')
ON CONFLICT (name) DO NOTHING;

INSERT INTO modules (name) VALUES
  ('Sala de Aula'),
  ('Laboratorios'),
  ('Laboratorio de Informatica'),
  ('Manutencao'),
  ('Almoxarifado')
ON CONFLICT (name) DO NOTHING;

INSERT INTO users (role_id, name, email, password_hash)
SELECT id, 'Administrador', 'admin@sga.local', crypt('123456', gen_salt('bf'))
FROM roles
WHERE name = 'Administrador'
ON CONFLICT (email) DO NOTHING;

INSERT INTO environments (module_id, code, name, block, capacity, responsible_name, default_period)
SELECT m.id, data.code, data.name, data.block, data.capacity, data.responsible_name, data.default_period
FROM (VALUES
  ('SA-101', 'Sala de Aula 101', 'Bloco A', 40, 'Responsavel do ambiente', 'Semanal'),
  ('LAB-Q', 'Laboratorio de Quimica', 'Bloco B', 25, 'Responsavel do ambiente', 'Semanal'),
  ('LAB-INF-01', 'Laboratorio de Informatica 01', 'Bloco C', 30, 'Responsavel do ambiente', 'Diaria'),
  ('OF-MAN', 'Oficina de Manutencao', 'Bloco D', 12, 'Equipe de Manutencao', 'Mensal'),
  ('ALM-01', 'Almoxarifado Central', 'Bloco E', 0, 'Almoxarifado', 'Semanal')
) AS data(code, name, block, capacity, responsible_name, default_period)
JOIN modules m ON m.name = CASE
  WHEN data.code = 'SA-101' THEN 'Sala de Aula'
  WHEN data.code = 'LAB-Q' THEN 'Laboratorios'
  WHEN data.code = 'LAB-INF-01' THEN 'Laboratorio de Informatica'
  WHEN data.code = 'OF-MAN' THEN 'Manutencao'
  ELSE 'Almoxarifado'
END
ON CONFLICT (code) DO NOTHING;

INSERT INTO checklist_items (module_id, name)
SELECT m.id, item.name
FROM modules m
JOIN (VALUES
  ('Sala de Aula', 'Ar-condicionado'), ('Sala de Aula', 'Data show / projetor'),
  ('Sala de Aula', 'Carteiras'), ('Sala de Aula', 'Mesa do professor'),
  ('Sala de Aula', 'Quadro branco'), ('Sala de Aula', 'Iluminacao'),
  ('Laboratorios', 'Ar-condicionado'), ('Laboratorios', 'EPI'),
  ('Laboratorios', 'Equipamentos patrimoniados'), ('Laboratorios', 'Materiais didaticos'),
  ('Laboratorio de Informatica', 'Computadores'), ('Laboratorio de Informatica', 'Monitores'),
  ('Laboratorio de Informatica', 'Teclados'), ('Laboratorio de Informatica', 'Mouses'),
  ('Laboratorio de Informatica', 'Estabilizadores / nobreaks'), ('Laboratorio de Informatica', 'Switches')
) AS item(module_name, name) ON item.module_name = m.name
ON CONFLICT (module_id, name) DO NOTHING;

INSERT INTO stock_items (code, name, category, quantity, minimum_quantity, unit, location)
VALUES
  ('EST-001', 'Lampada LED 18W', 'Material de consumo', 8, 10, 'un', 'Prateleira A1'),
  ('EPI-002', 'Oculos de protecao', 'EPI', 42, 20, 'un', 'Prateleira B2'),
  ('FER-014', 'Furadeira', 'Ferramenta', 3, 2, 'un', 'Armario C1'),
  ('MAT-020', 'Cabo HDMI', 'Material de consumo', 4, 5, 'un', 'Prateleira A3'),
  ('PAT-031', 'Notebook Patrimonio 031', 'Patrimoniado', 1, 0, 'un', 'LAB-INF-01')
ON CONFLICT (code) DO NOTHING;
