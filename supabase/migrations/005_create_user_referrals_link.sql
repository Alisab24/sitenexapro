-- ========================================
-- Create User Referrals Link Table
-- LeadQualif Partner Referral System
-- ========================================

CREATE TABLE IF NOT EXISTS public.user_referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL, -- Links to your existing users table
    referral_id UUID NOT NULL REFERENCES public.referrals(id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, referral_id) -- Prevent duplicate links
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_referrals_user_id ON public.user_referrals(user_id);
CREATE INDEX IF NOT EXISTS idx_user_referrals_referral_id ON public.user_referrals(referral_id);
CREATE INDEX IF NOT EXISTS idx_user_referrals_partner_id ON public.user_referrals(partner_id);

-- RLS (Row Level Security)
ALTER TABLE public.user_referrals ENABLE ROW LEVEL SECURITY;

-- Function to link user to referral on signup
CREATE OR REPLACE FUNCTION public.link_user_to_referral(
    p_user_id UUID,
    p_referral_code TEXT
)
RETURNS UUID AS $$
DECLARE
    v_referral_id UUID;
    v_partner_id UUID;
BEGIN
    -- Find the referral record
    SELECT id, partner_id INTO v_referral_id, v_partner_id
    FROM public.referrals 
    WHERE referral_code = p_referral_code 
    AND user_id IS NULL
    LIMIT 1;
    
    -- If referral found and not already linked
    IF v_referral_id IS NOT NULL THEN
        -- Create the link
        INSERT INTO public.user_referrals (user_id, referral_id, partner_id)
        VALUES (p_user_id, v_referral_id, v_partner_id);
        
        -- Update referral with signup date
        UPDATE public.referrals 
        SET user_id = p_user_id, 
            signup_date = NOW(),
            status = 'trial'
        WHERE id = v_referral_id;
        
        RETURN v_referral_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's referral info
CREATE OR REPLACE FUNCTION public.get_user_referral_info(p_user_id UUID)
RETURNS TABLE (
    referral_id UUID,
    partner_name TEXT,
    partner_email TEXT,
    referral_code TEXT,
    signup_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.referral_id,
        p.name as partner_name,
        p.email as partner_email,
        r.referral_code,
        r.signup_date
    FROM public.user_referrals ur
    JOIN public.referrals r ON ur.referral_id = r.id
    JOIN public.partners p ON ur.partner_id = p.id
    WHERE ur.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
-- Users can view their own referral links
CREATE POLICY "Users can view own referral links" ON public.user_referrals
    FOR ALL USING (auth.uid()::text = user_id::text);

-- Service role can manage all user referrals
CREATE POLICY "Service role can manage all user referrals" ON public.user_referrals
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Prevent duplicate user-referral links
CREATE POLICY "Prevent duplicate user referral links" ON public.user_referrals
    FOR INSERT WITH CHECK (NOT EXISTS (
        SELECT 1 FROM public.user_referrals 
        WHERE user_id = NEW.user_id 
        AND referral_id = NEW.referral_id
    ));
