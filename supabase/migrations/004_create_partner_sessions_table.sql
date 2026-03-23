-- ========================================
-- Create Partner Sessions Table
-- LeadQualif Partner Referral System
-- ========================================

CREATE TABLE IF NOT EXISTS public.partner_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_partner_sessions_token ON public.partner_sessions(token);
CREATE INDEX IF NOT EXISTS idx_partner_sessions_partner_id ON public.partner_sessions(partner_id);
CREATE INDEX IF NOT EXISTS idx_partner_sessions_expires_at ON public.partner_sessions(expires_at);

-- RLS (Row Level Security)
ALTER TABLE public.partner_sessions ENABLE ROW LEVEL SECURITY;

-- Function to clean expired sessions
CREATE OR REPLACE FUNCTION public.clean_expired_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM public.partner_sessions WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate session token
CREATE OR REPLACE FUNCTION public.generate_partner_token(p_partner_id UUID)
RETURNS TEXT AS $$
DECLARE
    token_payload JSON;
    token_text TEXT;
BEGIN
    -- Create JWT-like token (simplified for demo)
    token_payload := json_build_object(
        'partner_id', p_partner_id,
        'exp', EXTRACT(EPOCH FROM (NOW() + INTERVAL '7 days'))
    );
    
    token_text := encode(token_payload::text, 'base64');
    RETURN token_text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies
-- Partners can manage their own sessions
CREATE POLICY "Partners can manage own sessions" ON public.partner_sessions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.partners 
            WHERE id = partner_id 
            AND auth.uid()::text = public.partners.id::text
        )
    );

-- Service role can manage all sessions
CREATE POLICY "Service role can manage all sessions" ON public.partner_sessions
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Auto-cleanup expired sessions (run daily)
-- This would be called by a scheduled job or cron
SELECT public.clean_expired_sessions();
