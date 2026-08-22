-- ==============================================================================
-- ALI DATES (تمور علي) - CLEAN PRODUCTION DATABASE SCHEMA (NO SAMPLE DATA)
-- ==============================================================================

-- 1. PROFILES & CONTACTS TABLE (Synchronized with Odoo res.partner & App Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    is_employee BOOLEAN DEFAULT false,
    company_name TEXT DEFAULT 'تمور علي',
    password_hash TEXT DEFAULT '1234',
    needs_password_change BOOLEAN DEFAULT true,
    odoo_partner_id INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. FARMS TABLE
CREATE TABLE IF NOT EXISTS public.farms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    governorate TEXT NOT NULL,
    code TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. SHIPMENTS TABLE
CREATE TABLE IF NOT EXISTS public.shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_number SERIAL,
    direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    cargo_type TEXT NOT NULL CHECK (cargo_type IN ('dates', 'boxes')),
    customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
    driver_name TEXT,
    agent_name TEXT,
    plate_number TEXT,
    truck_photo_url TEXT,
    license_photo_url TEXT,
    is_presorted BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. PALLETS TABLE
CREATE TABLE IF NOT EXISTS public.pallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pallet_code TEXT UNIQUE NOT NULL,
    shipment_id UUID REFERENCES public.shipments(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
    empty_pallet_weight NUMERIC(6,2) DEFAULT 16.0,
    empty_box_weight NUMERIC(5,3) DEFAULT 0.95,
    box_count INTEGER DEFAULT 200,
    gross_weight NUMERIC(7,2) NOT NULL,
    net_weight NUMERIC(7,2) NOT NULL,
    location_type TEXT NOT NULL DEFAULT 'pre_fridge',
    freezer_row TEXT,
    freezer_col INTEGER,
    freezer_layer INTEGER,
    location_code TEXT,
    status TEXT DEFAULT 'received' CHECK (status IN ('received', 'stored', 'in_presort', 'in_autosort', 'sorted', 'delivered', 'consumed')),
    is_presorted BOOLEAN DEFAULT false,
    category TEXT,
    size TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. FIELD BOXES TABLE
CREATE TABLE IF NOT EXISTS public.field_boxes_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID REFERENCES public.shipments(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    box_count INTEGER NOT NULL,
    damaged_count INTEGER DEFAULT 0,
    lost_count INTEGER DEFAULT 0,
    rental_duration_days INTEGER DEFAULT 0,
    rental_price_per_box NUMERIC(6,3) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. SORTING BATCHES TABLE
CREATE TABLE IF NOT EXISTS public.sorting_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_number SERIAL,
    source_pallet_id UUID REFERENCES public.pallets(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    farm_id UUID REFERENCES public.farms(id) ON DELETE SET NULL,
    sorting_type TEXT NOT NULL CHECK (sorting_type IN ('presort', 'autosort')),
    scheduled_date DATE,
    input_weight NUMERIC(7,2) NOT NULL,
    output_weight NUMERIC(7,2) DEFAULT 0.0,
    waste_weight NUMERIC(7,2) DEFAULT 0.0,
    waste_details JSONB,
    status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- 7. SORTING OUTPUT PALLETS TABLE
CREATE TABLE IF NOT EXISTS public.sorting_outputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID REFERENCES public.sorting_batches(id) ON DELETE CASCADE,
    pallet_code TEXT NOT NULL,
    category TEXT NOT NULL,
    size TEXT NOT NULL,
    box_count INTEGER NOT NULL,
    weight NUMERIC(7,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. DOCUMENTS TABLE
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
-- ROW LEVEL SECURITY (RLS) POLICIES
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
