-- ========================================
-- Create Commissions Table
-- LeadQualif Partner Referral System
-- ========================================

CREATE TABLE IF NOT EXISTS public.commissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
    referral_id UUID NOT NULL REFERENCES public.referrals(id) ON DELETE CASCADE,
    subscription_id TEXT, -- Stripe subscription ID
    amount DECIMAL(10,2) NOT NULL,
    commission_amount DECIMAL(10,2) NOT NULL,
    commission_rate DECIMAL(5,2) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_commissions_partner_id ON public.commissions(partner_id);
CREATE INDEX IF NOT EXISTS idx_commissions_referral_id ON public.commissions(referral_id);
CREATE INDEX IF NOT EXISTS idx_commissions_status ON public.commissions(status);
CREATE INDEX IF NOT EXISTS idx_commissions_created_at ON public.commissions(created_at);
CREATE INDEX IF NOT EXISTS idx_commissions_paid_at ON public.commissions(paid_at);

-- RLS (Row Level Security)
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;

-- Function to calculate commission amount
CREATE OR REPLACE FUNCTION public.calculate_commission(
    p_amount DECIMAL,
    p_rate DECIMAL
)
RETURNS DECIMAL AS $$
BEGIN
    RETURN p_amount * p_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get monthly commission total
CREATE OR REPLACE FUNCTION public.get_monthly_commission_total(p_partner_id UUID)
RETURNS DECIMAL AS $$
BEGIN
    RETURN COALESCE(
        (
            SELECT SUM(commission_amount)
            FROM public.commissions 
            WHERE partner_id = p_partner_id 
            AND status = 'paid'
            AND created_at >= date_trunc('month', NOW())
        ), 0
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
-- Partners can view their own commissions
CREATE POLICY "Partners can view own commissions" ON public.commissions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.partners 
            WHERE id = partner_id 
            AND auth.uid()::text = public.partners.id::text
        )
    );

-- Service role can manage all commissions
CREATE POLICY "Service role can manage all commissions" ON public.commissions
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');
