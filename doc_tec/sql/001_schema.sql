CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(80) NOT NULL UNIQUE,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid NOT NULL REFERENCES roles(id),
  name varchar(160) NOT NULL,
  email varchar(255) NOT NULL UNIQUE,
  password_hash text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(120) NOT NULL UNIQUE,
  description text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS environments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id uuid NOT NULL REFERENCES modules(id),
  code varchar(40) NOT NULL UNIQUE,
  name varchar(160) NOT NULL,
  block varchar(100),
  capacity integer NOT NULL DEFAULT 0 CHECK (capacity >= 0),
  responsible_name varchar(160),
  default_period varchar(20) NOT NULL DEFAULT 'Semanal' CHECK (default_period IN ('Diaria', 'Semanal', 'Mensal')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_environment_permissions (
  user_id uuid NOT NULL REFERENCES users(id),
  environment_id uuid NOT NULL REFERENCES environments(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, environment_id)
);

CREATE TABLE IF NOT EXISTS checklist_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id uuid NOT NULL REFERENCES modules(id),
  name varchar(180) NOT NULL,
  item_type varchar(40) NOT NULL DEFAULT 'Equipamento / item',
  requires_evidence boolean NOT NULL DEFAULT false,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (module_id, name)
);

CREATE TABLE IF NOT EXISTS checklist_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  environment_id uuid NOT NULL REFERENCES environments(id),
  responsible_user_id uuid REFERENCES users(id),
  period varchar(20) NOT NULL CHECK (period IN ('Diaria', 'Semanal', 'Mensal')),
  next_execution_date date NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS checklist_executions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid REFERENCES checklist_schedules(id),
  environment_id uuid NOT NULL REFERENCES environments(id),
  executor_user_id uuid NOT NULL REFERENCES users(id),
  period varchar(20) NOT NULL CHECK (period IN ('Diaria', 'Semanal', 'Mensal')),
  execution_date date NOT NULL DEFAULT CURRENT_DATE,
  status varchar(30) NOT NULL DEFAULT 'Em preenchimento' CHECK (status IN ('Em preenchimento', 'Concluida', 'Cancelada')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS checklist_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  execution_id uuid NOT NULL REFERENCES checklist_executions(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES checklist_items(id),
  status varchar(35) NOT NULL CHECK (status IN ('Conforme', 'Parcialmente conforme', 'Nao conforme', 'Nao se aplica', 'Nao verificado')),
  observation text,
  evidence_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (execution_id, item_id),
  CONSTRAINT irregular_answer_requires_observation CHECK (
    status NOT IN ('Parcialmente conforme', 'Nao conforme', 'Nao verificado')
    OR nullif(trim(observation), '') IS NOT NULL
  )
);

CREATE TABLE IF NOT EXISTS maintenance_occurrences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  protocol varchar(30) NOT NULL UNIQUE,
  environment_id uuid NOT NULL REFERENCES environments(id),
  checklist_answer_id uuid REFERENCES checklist_answers(id),
  reported_by_user_id uuid NOT NULL REFERENCES users(id),
  item_name varchar(180) NOT NULL,
  description text NOT NULL,
  priority varchar(20) NOT NULL DEFAULT 'Media' CHECK (priority IN ('Baixa', 'Media', 'Alta', 'Critica')),
  status varchar(30) NOT NULL DEFAULT 'Aberta' CHECK (status IN ('Aberta', 'Em triagem', 'Em atendimento', 'Aguardando material', 'Concluida', 'Validada', 'Encerrada', 'Cancelada')),
  validated_by_user_id uuid REFERENCES users(id),
  validated_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stock_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(40) NOT NULL UNIQUE,
  name varchar(180) NOT NULL,
  category varchar(40) NOT NULL CHECK (category IN ('Equipamento', 'Ferramenta', 'Patrimoniado', 'Material de consumo', 'EPI', 'Peca')),
  patrimony_number varchar(80) UNIQUE,
  quantity numeric(12,2) NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  minimum_quantity numeric(12,2) NOT NULL DEFAULT 0 CHECK (minimum_quantity >= 0),
  unit varchar(20) NOT NULL DEFAULT 'un',
  location varchar(120),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_item_id uuid NOT NULL REFERENCES stock_items(id),
  user_id uuid NOT NULL REFERENCES users(id),
  movement_type varchar(20) NOT NULL CHECK (movement_type IN ('Entrada', 'Saida', 'Ajuste')),
  quantity numeric(12,2) NOT NULL CHECK (quantity > 0),
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS loans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  borrower_user_id uuid NOT NULL REFERENCES users(id),
  expected_return_at timestamptz NOT NULL,
  returned_at timestamptz,
  status varchar(20) NOT NULL DEFAULT 'Ativo' CHECK (status IN ('Ativo', 'Devolvido', 'Atrasado', 'Cancelado')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS loan_items (
  loan_id uuid NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  stock_item_id uuid NOT NULL REFERENCES stock_items(id),
  quantity numeric(12,2) NOT NULL CHECK (quantity > 0),
  returned_quantity numeric(12,2) NOT NULL DEFAULT 0 CHECK (returned_quantity >= 0 AND returned_quantity <= quantity),
  PRIMARY KEY (loan_id, stock_item_id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  action varchar(80) NOT NULL,
  entity_type varchar(80) NOT NULL,
  entity_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_environments_module ON environments(module_id);
CREATE INDEX IF NOT EXISTS idx_checklist_executions_environment_date ON checklist_executions(environment_id, execution_date DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_occurrences_status ON maintenance_occurrences(status);
CREATE INDEX IF NOT EXISTS idx_stock_movements_item_date ON stock_movements(stock_item_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at DESC);

DROP TRIGGER IF EXISTS users_updated_at ON users;
CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS modules_updated_at ON modules;
CREATE TRIGGER modules_updated_at BEFORE UPDATE ON modules FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS environments_updated_at ON environments;
CREATE TRIGGER environments_updated_at BEFORE UPDATE ON environments FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS checklist_items_updated_at ON checklist_items;
CREATE TRIGGER checklist_items_updated_at BEFORE UPDATE ON checklist_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS checklist_schedules_updated_at ON checklist_schedules;
CREATE TRIGGER checklist_schedules_updated_at BEFORE UPDATE ON checklist_schedules FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS checklist_executions_updated_at ON checklist_executions;
CREATE TRIGGER checklist_executions_updated_at BEFORE UPDATE ON checklist_executions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS checklist_answers_updated_at ON checklist_answers;
CREATE TRIGGER checklist_answers_updated_at BEFORE UPDATE ON checklist_answers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS maintenance_occurrences_updated_at ON maintenance_occurrences;
CREATE TRIGGER maintenance_occurrences_updated_at BEFORE UPDATE ON maintenance_occurrences FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS stock_items_updated_at ON stock_items;
CREATE TRIGGER stock_items_updated_at BEFORE UPDATE ON stock_items FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS loans_updated_at ON loans;
CREATE TRIGGER loans_updated_at BEFORE UPDATE ON loans FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION prevent_negative_stock()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.movement_type = 'Saida' AND (SELECT quantity FROM stock_items WHERE id = NEW.stock_item_id) < NEW.quantity THEN
    RAISE EXCEPTION 'Saldo insuficiente para o item de estoque %', NEW.stock_item_id;
  END IF;

  UPDATE stock_items
  SET quantity = CASE NEW.movement_type
    WHEN 'Entrada' THEN quantity + NEW.quantity
    WHEN 'Saida' THEN quantity - NEW.quantity
    ELSE NEW.quantity
  END
  WHERE id = NEW.stock_item_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS apply_stock_movement ON stock_movements;
CREATE TRIGGER apply_stock_movement
AFTER INSERT ON stock_movements
FOR EACH ROW EXECUTE FUNCTION prevent_negative_stock();
