-- ========================================
-- Create Partners Table
-- LeadQualif Partner Referral System
-- ========================================

CREATE TABLE IF NOT EXISTS public.partners (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    company TEXT,
    website TEXT,
    audience_type TEXT CHECK (audience_type IN ('marketing_agency', 'crm_consultant', 'lead_generation', 'growth_consultant', 'sales_coach', 'b2b_influencer')),
    audience_size TEXT CHECK (audience_size IN ('<1k', '1k-10k', '10k-50k', '50k-100k', '>100k')),
    promotion_strategy TEXT,
    country TEXT,
    referral_code TEXT UNIQUE NOT NULL,
    commission_rate DECIMAL(5,2) DEFAULT 0.30,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_partners_email ON public.partners(email);
CREATE INDEX IF NOT EXISTS idx_partners_referral_code ON public.partners(referral_code);
CREATE INDEX IF NOT EXISTS idx_partners_status ON public.partners(status);
CREATE INDEX IF NOT EXISTS idx_partners_audience_type ON public.partners(audience_type);

-- RLS (Row Level Security) - Partners can only see their own data
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION public.generate_referral_code(partner_name TEXT)
RETURNS TEXT AS $$
DECLARE
    base_name TEXT;
    random_suffix TEXT;
    referral_code TEXT;
    attempts INTEGER := 0;
    max_attempts INTEGER := 10;
BEGIN
    -- Extract first part of name and normalize
    base_name := LOWER(REGEXP_REPLACE(partner_name, '[^a-zA-Z0-9]', '', 'g'));
    base_name := LEFT(base_name, 8);
    
    LOOP
        -- Generate random suffix
        random_suffix := LOWER(substring(encode(gen_random_bytes(2), 'hex'), 1, 4));
        referral_code := base_name || '_' || random_suffix;
        
        -- Check if code exists
        IF NOT EXISTS (SELECT 1 FROM public.partners WHERE referral_code = referral_code) THEN
            RETURN referral_code;
        END IF;
        
        attempts := attempts + 1;
        IF attempts >= max_attempts THEN
            -- Fallback to completely random code
            referral_code := 'partner_' || LOWER(substring(encode(gen_random_bytes(4), 'hex'), 1, 8));
            RETURN referral_code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to automatically generate referral code
CREATE OR REPLACE FUNCTION public.set_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
        NEW.referral_code := public.generate_referral_code(NEW.name);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for auto referral code generation
CREATE TRIGGER set_partner_referral_code
    BEFORE INSERT ON public.partners
    FOR EACH ROW
    EXECUTE FUNCTION public.set_referral_code();

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER update_partners_updated_at 
    BEFORE UPDATE ON public.partners 
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_updated_at_column();

-- RLS Policies
-- Partners can only see their own data
CREATE POLICY "Users can view own partner data" ON public.partners
    FOR ALL USING (auth.uid()::text = id::text);

-- Service role for full access
CREATE POLICY "Service role can manage all partners" ON public.partners
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');
