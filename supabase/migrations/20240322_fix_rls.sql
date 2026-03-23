-- Step 2: Fix RLS Policies for every user-owned table

-- Onboarding
ALTER TABLE public.onboarding ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.onboarding FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.onboarding FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.onboarding FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.onboarding FOR DELETE USING (auth.uid() = user_id);

-- User Goals
ALTER TABLE public.user_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.user_goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.user_goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.user_goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.user_goals FOR DELETE USING (auth.uid() = user_id);

-- Nutrition Logs
ALTER TABLE public.nutrition_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.nutrition_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.nutrition_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.nutrition_logs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.nutrition_logs FOR DELETE USING (auth.uid() = user_id);

-- Workout Sessions
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.workout_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.workout_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.workout_sessions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.workout_sessions FOR DELETE USING (auth.uid() = user_id);

-- Workout Sets
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.workout_sets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.workout_sets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.workout_sets FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.workout_sets FOR DELETE USING (auth.uid() = user_id);

-- Daily Summary
ALTER TABLE public.daily_summary ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.daily_summary FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.daily_summary FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.daily_summary FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.daily_summary FOR DELETE USING (auth.uid() = user_id);

-- Weekly Activity
ALTER TABLE public.weekly_activity ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.weekly_activity FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.weekly_activity FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.weekly_activity FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.weekly_activity FOR DELETE USING (auth.uid() = user_id);

-- Body Measurements
ALTER TABLE public.body_measurements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.body_measurements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.body_measurements FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.body_measurements FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.body_measurements FOR DELETE USING (auth.uid() = user_id);

-- User Programs
ALTER TABLE public.user_programs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own data" ON public.user_programs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own data" ON public.user_programs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own data" ON public.user_programs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own data" ON public.user_programs FOR DELETE USING (auth.uid() = user_id);

-- Profiles Table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Foods Table
ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view foods" ON public.foods FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert foods" ON public.foods FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Step 3: Add Profile Auto-Creation Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, created_at, updated_at)
  VALUES (new.id, new.email, now(), now())
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
