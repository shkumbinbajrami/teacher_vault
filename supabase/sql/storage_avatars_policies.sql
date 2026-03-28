-- Run in Supabase → SQL Editor after creating bucket `avatars`.
-- App uploads to: avatars / teachers/{teacher_id}/{filename}

-- Optional: start clean (ignore errors if policies did not exist)
DROP POLICY IF EXISTS "Avatars: public read" ON storage.objects;
DROP POLICY IF EXISTS "Avatars: teachers upload own folder" ON storage.objects;
DROP POLICY IF EXISTS "Avatars: teachers update own folder" ON storage.objects;
DROP POLICY IF EXISTS "Avatars: teachers delete own folder" ON storage.objects;

-- Anyone can fetch objects (needed for public URLs / NetworkImage).
CREATE POLICY "Avatars: public read"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Signed-in users may upload only under teachers/{their_teacher_row_id}/...
CREATE POLICY "Avatars: teachers upload own folder"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND COALESCE(split_part(name, '/', 1), '') = 'teachers'
  AND EXISTS (
    SELECT 1
    FROM public.teachers t
    WHERE t.id::text = split_part(name, '/', 2)
      AND t.user_id = auth.uid()
  )
);

-- uploadBinary(..., upsert: true) can issue updates when replacing the same path
CREATE POLICY "Avatars: teachers update own folder"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND COALESCE(split_part(name, '/', 1), '') = 'teachers'
  AND EXISTS (
    SELECT 1
    FROM public.teachers t
    WHERE t.id::text = split_part(name, '/', 2)
      AND t.user_id = auth.uid()
  )
)
WITH CHECK (
  bucket_id = 'avatars'
  AND COALESCE(split_part(name, '/', 1), '') = 'teachers'
  AND EXISTS (
    SELECT 1
    FROM public.teachers t
    WHERE t.id::text = split_part(name, '/', 2)
      AND t.user_id = auth.uid()
  )
);

-- Optional: let users remove old files in their folder
CREATE POLICY "Avatars: teachers delete own folder"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND COALESCE(split_part(name, '/', 1), '') = 'teachers'
  AND EXISTS (
    SELECT 1
    FROM public.teachers t
    WHERE t.id::text = split_part(name, '/', 2)
      AND t.user_id = auth.uid()
  )
);
