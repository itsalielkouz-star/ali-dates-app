-- ==============================================================================
-- ALI DATES (تمور علي) - COMPLETE DATABASE SCHEMA FOR SUPABASE
-- Optimized for Free Tier (< 500MB DB, < 1GB Storage)
-- ==============================================================================

-- 1. PROFILES & CONTACTS TABLE (Synchronized with Odoo res.partner & App Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    is_employee BOOLEAN DEFAULT false,
    company_name TEXT DEFAULT 'تمور علي',
    password_hash TEXT DEFAULT '1234', -- Default password flag
    needs_password_change BOOLEAN DEFAULT true,
    odoo_partner_id INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. FARMS TABLE (مزارع العملاء)
CREATE TABLE IF NOT EXISTS public.farms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    governorate TEXT NOT NULL, -- المحافظة أو المنطقة (e.g. الأغوار الجنوبية، دير علا، الكرامة، الأزرق)
    code TEXT, -- كود المزرعة (اختياري)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. SHIPMENTS TABLE (سندات حركة الشاحنات والاستلام والتسليم)
CREATE TABLE IF NOT EXISTS public.shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_number SERIAL,
    direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')), -- استلام vs تسليم
    cargo_type TEXT NOT NULL CHECK (cargo_type IN ('dates', 'boxes')), -- تمور vs صناديق حقل
    customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
    driver_name TEXT,
    agent_name TEXT, -- اسم وكيل العميل أو المشرف
    plate_number TEXT, -- رقم لوحة المركبة
    truck_photo_url TEXT,
    license_photo_url TEXT,
    is_presorted BOOLEAN DEFAULT false, -- مفروز أولي (checkbox)
    status TEXT DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. PALLETS TABLE (طبالي التمور في المستودع)
CREATE TABLE IF NOT EXISTS public.pallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pallet_code TEXT UNIQUE NOT NULL, -- مثل: PAL-2026-001 أو كود QR
    shipment_id UUID REFERENCES public.shipments(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
    empty_pallet_weight NUMERIC(6,2) DEFAULT 16.0, -- وزن الطبلية الفارغة (الافتراضي 16 كغ)
    empty_box_weight NUMERIC(5,3) DEFAULT 0.95, -- وزن الصندوق الفارغ (الافتراضي 0.95 كغ)
    box_count INTEGER DEFAULT 200, -- عدد الصناديق
    gross_weight NUMERIC(7,2) NOT NULL, -- الوزن الإجمالي
    net_weight NUMERIC(7,2) NOT NULL, -- الوزن الصافي المحسوب
    location_type TEXT NOT NULL DEFAULT 'pre_fridge', 
    -- 'pre_fridge' (ثلاجة التعقيم), 'first_fridge' (التبريد الأولي), 
    -- 'main_freezer_1' (الفريزر 1), 'main_freezer_2' (الفريزر 2), 
    -- 'small_freezer' (الفريزر الصغير), 'presort' (فرز أولي), 'autosort' (فرز آلي), 'delivered' (تم التسليم)
    freezer_row TEXT, -- صف الفريزر من A إلى O
    freezer_col INTEGER, -- عمود الفريزر من 1 إلى 6
    freezer_layer INTEGER, -- الطبقة من 1 إلى 3
    location_code TEXT, -- مثل: A11, O63
    status TEXT DEFAULT 'received' CHECK (status IN ('received', 'stored', 'in_presort', 'in_autosort', 'sorted', 'delivered', 'consumed')),
    is_presorted BOOLEAN DEFAULT false,
    category TEXT, -- للأصناف المفروزة آلياً: بريميوم، ديلايت، كلاسيك... إلخ
    size TEXT, -- للأحجام: سوبر جمبو، جمبو، لارج... إلخ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. FIELD BOXES TABLE (حركات صناديق الحقل)
CREATE TABLE IF NOT EXISTS public.field_boxes_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID REFERENCES public.shipments(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    box_count INTEGER NOT NULL,
    damaged_count INTEGER DEFAULT 0, -- التالف
    lost_count INTEGER DEFAULT 0, -- مفقود
    rental_duration_days INTEGER DEFAULT 0, -- مدة الإيجار
    rental_price_per_box NUMERIC(6,3) DEFAULT 0.0, -- إيجار الصندوق بالدينار
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. SORTING BATCHES (دفعات الفرز الأولي والفرز الآلي)
CREATE TABLE IF NOT EXISTS public.sorting_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_number SERIAL,
    source_pallet_id UUID REFERENCES public.pallets(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
    sorting_type TEXT NOT NULL CHECK (sorting_type IN ('presort', 'autosort')), -- فرز أولي vs فرز آلي
    scheduled_date DATE,
    input_weight NUMERIC(7,2) NOT NULL,
    output_weight NUMERIC(7,2) DEFAULT 0.0,
    waste_weight NUMERIC(7,2) DEFAULT 0.0, -- بضاعة تالفة / فاقد
    waste_details JSONB, -- تفصيل أصناف الفرز الأولي (أصفر، مفعوص، ناشف، نقرة عصفور، رطب)
    status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- 7. SORTING OUTPUT PALLETS (مخرجات الطبالي والصناديق من الفرز الآلي)
CREATE TABLE IF NOT EXISTS public.sorting_outputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID REFERENCES public.sorting_batches(id) ON DELETE CASCADE,
    pallet_code TEXT NOT NULL,
    category TEXT NOT NULL, -- بريميوم, ديلايت, كلاسيك, سوفت بريميوم, احمر أ, احمر ب, بون بون
    size TEXT NOT NULL, -- سوبر جمبو, جمبو, لارج, ميديوم, سمول, سمول بيبي
    box_count INTEGER NOT NULL, -- عدد الصناديق (كل صندوق 5 كغ)
    weight NUMERIC(7,2) NOT NULL, -- box_count * 5
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. DOCUMENTS TABLE (أرشيف السندات والتقارير الموقعة)
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    shipment_id UUID REFERENCES public.shipments(id) ON DELETE SET NULL,
    batch_id UUID REFERENCES public.sorting_batches(id) ON DELETE SET NULL,
    doc_type TEXT NOT NULL CHECK (doc_type IN ('receiving_receipt', 'sorting_report', 'delivery_note', 'boxes_receipt')),
    title TEXT NOT NULL,
    file_name TEXT NOT NULL,
    pdf_base64 TEXT,
    pdf_url TEXT,
    signature_base64 TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES - PERMIT APP ACCESS
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_boxes_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sorting_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sorting_outputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access to profiles" ON public.profiles;
CREATE POLICY "Allow public access to profiles" ON public.profiles FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to farms" ON public.farms;
CREATE POLICY "Allow public access to farms" ON public.farms FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to shipments" ON public.shipments;
CREATE POLICY "Allow public access to shipments" ON public.shipments FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to pallets" ON public.pallets;
CREATE POLICY "Allow public access to pallets" ON public.pallets FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to field_boxes_records" ON public.field_boxes_records;
CREATE POLICY "Allow public access to field_boxes_records" ON public.field_boxes_records FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to sorting_batches" ON public.sorting_batches;
CREATE POLICY "Allow public access to sorting_batches" ON public.sorting_batches FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to sorting_outputs" ON public.sorting_outputs;
CREATE POLICY "Allow public access to sorting_outputs" ON public.sorting_outputs FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public access to documents" ON public.documents;
CREATE POLICY "Allow public access to documents" ON public.documents FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- SEED INITIAL DATA FOR ALI DATES
-- ==============================================================================
INSERT INTO public.profiles (phone, name, is_employee, company_name, password_hash, needs_password_change)
VALUES 
('0791234567', 'علي الشريف (مدير المستودع)', true, 'تمور علي', '1234', true),
('0788888888', 'م. خالد الدباس (مشرف الجودة والفرز)', true, 'تمور علي', '1234', true),
('0777777777', 'مزرعة النخيل الذهبي - أبو راشد', false, 'مزارع النخيل الذهبي', '1234', true),
('0799999999', 'مزرعة بركات الأردن - الحاج فهد', false, 'مزارع بركات الأردن', '1234', true),
('0785555555', 'مزارع المجدول الملكي - دير علا', false, 'المجدول الملكي', '1234', true)
ON CONFLICT (phone) DO NOTHING;

-- INSERT SAMPLE FARMS
INSERT INTO public.farms (customer_id, name, governorate, code)
SELECT id, 'مزرعة وادي الأردن 1', 'الأغوار الجنوبية', 'F-JOR-01'
FROM public.profiles WHERE phone = '0777777777' LIMIT 1;

INSERT INTO public.farms (customer_id, name, governorate, code)
SELECT id, 'مزرعة النخيل النموذجية', 'دير علا', 'F-DEIR-04'
FROM public.profiles WHERE phone = '0799999999' LIMIT 1;
