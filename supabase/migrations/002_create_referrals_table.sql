-- ========================================
-- Create Referrals Table
-- LeadQualif Partner Referral System
-- ========================================

CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
    user_id UUID, -- Will link to users table when user signs up
    referral_code TEXT NOT NULL,
    signup_date TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'trial' CHECK (status IN ('trial', 'active', 'canceled')),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_referrals_partner_id ON public.referrals(partner_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referral_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);
CREATE INDEX IF NOT EXISTS idx_referrals_user_id ON public.referrals(user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_signup_date ON public.referrals(signup_date);

-- RLS (Row Level Security)
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- Function to check for duplicate referrals
CREATE OR REPLACE FUNCTION public.check_duplicate_referral(
    p_referral_code TEXT,
    p_ip_address INET DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if referral already exists from same IP within last hour
    RETURN EXISTS (
        SELECT 1 FROM public.referrals 
        WHERE referral_code = p_referral_code 
        AND ip_address = p_ip_address 
        AND created_at > NOW() - INTERVAL '1 hour'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
-- Partners can view their own referrals
CREATE POLICY "Partners can view own referrals" ON public.referrals
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.partners 
            WHERE id = partner_id 
            AND auth.uid()::text = public.partners.id::text
        )
    );

-- Service role can manage all referrals
CREATE POLICY "Service role can manage all referrals" ON public.referrals
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Prevent duplicate referrals from same IP
CREATE POLICY "Prevent duplicate referrals" ON public.referrals
    FOR INSERT WITH CHECK (NOT public.check_duplicate_referral(referral_code, ip_address));
