-- Junk supermarket snacks (owner brief 2026-09-24: "غير صحي بس محسوب السعرات")
-- for the suggest-meal treat style + the food library. Per-serving values.
-- Applied live via Management API on 2026-09-24; this file is the idempotent
-- record of that insert (skips names that already exist).
INSERT INTO foods (
  name, name_ar, category, is_custom,
  calories, protein_g, carbs_g, fat_g,
  fiber_g, sugars_g, sodium_mg,
  serving_size, serving_unit
)
SELECT
  v.name, v.name_ar, 'snacks', false,
  v.calories, v.protein_g, v.carbs_g, v.fat_g,
  v.fiber_g, v.sugars_g, v.sodium_mg,
  v.serving_size, v.serving_unit
FROM (VALUES
  ('Snickers Bar (50g)',              'سنيكرز',                     250, 4.3, 33,   12,   1.3, 25,  120, 50,   'g'),
  ('KitKat (2 fingers, 20.8g)',       'كيت كات (شريحتين)',           105, 1.5, 13.5,  5.2, 0.5, 10.5, 18, 20.8, 'g'),
  ('Galaxy Bar (42g)',                'جالاكسي',                    234, 3.0, 26,   13,   1.0, 23,  105, 42,   'g'),
  ('Twix Bar (50g)',                  'تويكس',                      250, 2.6, 33,   12,   0.9, 24,  130, 50,   'g'),
  ('Bounty Bar (57g)',                'بونتي',                      268, 2.0, 34,   14,   2.0, 28,  135, 57,   'g'),
  ('Kinder Bueno (43g)',              'كيندر بونو',                  246, 4.5, 23,   15,   0.8, 18,  130, 43,   'g'),
  ('M&M''s Peanut (47g)',             'ام اند امز بالفول السوداني',   250, 4.5, 28,   13,   1.4, 22,   65, 47,   'g'),
  ('Oreo (3 cookies, 33g)',           'أوريو (3 قطع)',               160, 1.6, 25,    6.5, 0.9, 14,  170, 33,   'g'),
  ('Cheetos (30g)',                   'شيتوس',                      170, 1.5, 16,   10.5, 0.5,  0.5, 290, 30,   'g'),
  ('Chipsy Cheese (45g)',             'شيبسي جبنة',                  240, 3.0, 23,   14.5, 1.5,  1.0, 380, 45,   'g'),
  ('Ringo (45g)',                     'رينجو',                      235, 3.0, 23,   14,   1.6,  1.0, 350, 45,   'g'),
  ('Gato Cake Slice (30g)',           'جاتو',                       135, 1.5, 17,    6.5, 0.4,  9,    95, 30,   'g'),
  ('Domino Sandwich Cookies (2 pcs)', 'دومينو (قطعتين)',             145, 2.0, 20,    6.0, 0.6,  8,    90, 30,   'g'),
  ('Bisco Misr (2 biscuits, 36g)',    'بيسكو مصر (قطعتين)',          168, 2.6, 24,    7,   0.9,  9,   130, 36,   'g'),
  ('Molto Croissant (55g)',           'مولتو كرواسون',               242, 4.0, 28,   12,   1.2, 10,   190, 55,   'g'),
  ('Nutella Portion (15g)',           'نوتيلا (عبوة فردية)',          80, 0.9,  8.6,  4.5, 0.5,  8,     5, 15,   'g')
) AS v(name, name_ar, calories, protein_g, carbs_g, fat_g, fiber_g, sugars_g, sodium_mg, serving_size, serving_unit)
WHERE NOT EXISTS (SELECT 1 FROM foods f WHERE f.name = v.name);
