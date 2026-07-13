-- =============================================================================
-- نسخ هذا الملف كاملاً إلى: Supabase Dashboard → SQL Editor → New query → Run
-- مشروع مهارات — جدول courses وحقل is_active (فتح / إغلاق الدورة)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) إنشاء الجدول إن لم يكن موجوداً
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.courses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL DEFAULT '',
    img text,
    terms text,
    objective text,
    axes jsonb DEFAULT '[]'::jsonb,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.courses IS 'دورات التدريب';
COMMENT ON COLUMN public.courses.is_active IS 'true = مفتوحة وتظهر في الموقع | false = مغلقة ولا تظهر';

-- -----------------------------------------------------------------------------
-- 2) إضافة الأعمدة الناقصة إن كان الجدول قديماً (بدون كسر البيانات)
-- -----------------------------------------------------------------------------
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS img text;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS terms text;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS objective text;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS axes jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS is_active boolean;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS created_at timestamptz;

UPDATE public.courses SET is_active = true WHERE is_active IS NULL;
ALTER TABLE public.courses ALTER COLUMN is_active SET DEFAULT true;
ALTER TABLE public.courses ALTER COLUMN is_active SET NOT NULL;

UPDATE public.courses SET axes = '[]'::jsonb WHERE axes IS NULL;
ALTER TABLE public.courses ALTER COLUMN axes SET DEFAULT '[]'::jsonb;

UPDATE public.courses SET created_at = now() WHERE created_at IS NULL;
ALTER TABLE public.courses ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE public.courses ALTER COLUMN created_at SET NOT NULL;

-- -----------------------------------------------------------------------------
-- 3) إن كان is_active محفوظاً كنص (text) بدلاً من boolean — تحويله
--    (يُتخطى تلقائياً إذا كان النوع boolean بالفعل)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'courses'
          AND column_name = 'is_active'
          AND data_type IN ('text', 'character varying')
    ) THEN
        ALTER TABLE public.courses
            ALTER COLUMN is_active TYPE boolean USING (
                CASE
                    WHEN trim(lower(is_active::text)) IN ('true', 't', '1', 'yes') THEN true
                    WHEN trim(lower(is_active::text)) IN ('false', 'f', '0', 'no') THEN false
                    ELSE true
                END
            );
        ALTER TABLE public.courses ALTER COLUMN is_active SET DEFAULT true;
        ALTER TABLE public.courses ALTER COLUMN is_active SET NOT NULL;
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 4) فهرس لتسريع: الدورات المفعّلة فقط + ترتيب التاريخ
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_courses_is_active_created
    ON public.courses (is_active, created_at DESC);

-- -----------------------------------------------------------------------------
-- 5) صلاحيات Supabase الافتراضية (آمنة للتكرار)
-- -----------------------------------------------------------------------------
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

-- احذف سياسات قديمة بنفس الأسماء إن وُجدت (لتجنب خطأ duplicate)
DROP POLICY IF EXISTS "courses_anon_select" ON public.courses;
DROP POLICY IF EXISTS "courses_anon_insert" ON public.courses;
DROP POLICY IF EXISTS "courses_anon_update" ON public.courses;
DROP POLICY IF EXISTS "courses_anon_delete" ON public.courses;
DROP POLICY IF EXISTS "courses_authenticated_select" ON public.courses;
DROP POLICY IF EXISTS "courses_authenticated_insert" ON public.courses;
DROP POLICY IF EXISTS "courses_authenticated_update" ON public.courses;
DROP POLICY IF EXISTS "courses_authenticated_delete" ON public.courses;

-- anon + authenticated: قراءة كل الصفوف (لوحة الليدر تحتاج ترى المغلقة أيضاً)
CREATE POLICY "courses_anon_select"
    ON public.courses FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "courses_authenticated_select"
    ON public.courses FOR SELECT
    TO authenticated
    USING (true);

-- إدراج وتعديل وحذف من الواجهة (مفتاح anon كما في مشروعك)
CREATE POLICY "courses_anon_insert"
    ON public.courses FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "courses_anon_update"
    ON public.courses FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "courses_anon_delete"
    ON public.courses FOR DELETE
    TO anon
    USING (true);

CREATE POLICY "courses_authenticated_insert"
    ON public.courses FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "courses_authenticated_update"
    ON public.courses FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "courses_authenticated_delete"
    ON public.courses FOR DELETE
    TO authenticated
    USING (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.courses TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.courses TO authenticated;
GRANT ALL ON public.courses TO service_role;

-- =============================================================================
-- انتهى. بعد التنفيذ:
-- - is_active = true  → تظهر في employee / Researcher (coursesCatalog.js)
-- - is_active = false → لا تُجلب في واجهة الزوار
-- تم إصلاح الواجهة أيضاً لتفرغ القائمة حتى لو أصبحت النتيجة [] فارغة.
-- =============================================================================
