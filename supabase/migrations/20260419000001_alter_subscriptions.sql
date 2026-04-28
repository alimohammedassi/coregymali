-- Add the missing columns to the existing 'subscriptions' table so our new Coach Dashboards can join and query properly.

ALTER TABLE subscriptions
ADD COLUMN IF NOT EXISTS plan_id uuid REFERENCES subscription_plans(id),
ADD COLUMN IF NOT EXISTS payment_status text CHECK (payment_status IN ('unpaid','paid','refunded')),
ADD COLUMN IF NOT EXISTS started_at timestamptz,
ADD COLUMN IF NOT EXISTS expires_at timestamptz,
ADD COLUMN IF NOT EXISTS goals text,
ADD COLUMN IF NOT EXISTS notes text;
