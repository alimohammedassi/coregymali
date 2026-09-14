-- 20260914120000_storage_food_images.sql
-- Dedicated bucket for food catalog images (foods.image_url already exists).
-- Public read (like coach-media / avatars); writes restricted to coaches,
-- scoped to their own auth.uid() top-level folder — same folder pattern the
-- chat and coach buckets use (chat_*_insert_participants joins a table in the
-- WITH_CHECK, this joins profiles for the role check).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'food-images',
  'food-images',
  true,
  5242880, -- 5 MB
  ARRAY['image/png', 'image/jpeg', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "food_images_public_read"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'food-images');

CREATE POLICY "food_images_coach_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'food-images'
    AND (storage.foldername(name))[1] = (auth.uid())::text
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'coach'
    )
  );

CREATE POLICY "food_images_coach_update"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'food-images'
    AND (storage.foldername(name))[1] = (auth.uid())::text
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'coach'
    )
  );

CREATE POLICY "food_images_coach_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'food-images'
    AND (storage.foldername(name))[1] = (auth.uid())::text
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'coach'
    )
  );
