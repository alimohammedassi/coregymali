-- subscription_plans
CREATE TABLE IF NOT EXISTS subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES profiles(id),
  name text NOT NULL,
  price_usd numeric(10,2),
  duration_days int,
  max_clients int,
  created_at timestamptz DEFAULT now()
);

-- subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id uuid REFERENCES profiles(id),
  client_id uuid REFERENCES profiles(id),
  plan_id uuid REFERENCES subscription_plans(id),
  status text CHECK (status IN ('pending','active','paused','expired','cancelled')),
  payment_status text CHECK (payment_status IN ('unpaid','paid','refunded')),
  started_at timestamptz,
  expires_at timestamptz,
  goals text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- subscription_phases
CREATE TABLE IF NOT EXISTS subscription_phases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id uuid REFERENCES subscriptions(id) ON DELETE CASCADE,
  phase_number int NOT NULL,
  title text NOT NULL,
  type text CHECK (type IN ('workout','nutrition','combined')),
  description text,
  duration_weeks int,
  status text CHECK (status IN ('upcoming','in_progress','completed')),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- RLS Policies

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_phases ENABLE ROW LEVEL SECURITY;

-- subscription_plans
CREATE POLICY "coach SELECT/INSERT/UPDATE" ON subscription_plans
  FOR ALL
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

-- subscriptions
CREATE POLICY "coach SELECT/UPDATE" ON subscriptions
  FOR ALL
  USING (coach_id = auth.uid())
  WITH CHECK (coach_id = auth.uid());

CREATE POLICY "client SELECT" ON subscriptions
  FOR SELECT
  USING (client_id = auth.uid());

-- subscription_phases
CREATE POLICY "coach SELECT/INSERT/UPDATE via subscription" ON subscription_phases
  FOR ALL
  USING (EXISTS (SELECT 1 FROM subscriptions cs WHERE cs.id = subscription_id AND cs.coach_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM subscriptions cs WHERE cs.id = subscription_id AND cs.coach_id = auth.uid()));

CREATE POLICY "client SELECT via subscription" ON subscription_phases
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM subscriptions cs WHERE cs.id = subscription_id AND cs.client_id = auth.uid()));
