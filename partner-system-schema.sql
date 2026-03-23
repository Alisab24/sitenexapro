-- ========================================
-- LEADQUALIF PARTNER REFERRAL SYSTEM
-- MVP Database Schema
-- ========================================

-- Partners table
CREATE TABLE partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    company VARCHAR(255),
    website VARCHAR(500),
    audience_type VARCHAR(100) CHECK (audience_type IN ('marketing_agency', 'crm_consultant', 'lead_generation', 'growth_consultant', 'sales_coach', 'b2b_influencer')),
    audience_size VARCHAR(50) CHECK (audience_size IN ('<1k', '1k-10k', '10k-50k', '50k-100k', '>100k')),
    promotion_strategy TEXT,
    country VARCHAR(100),
    referral_code VARCHAR(50) UNIQUE NOT NULL,
    commission_rate DECIMAL(5,2) DEFAULT 0.30,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Referrals table
CREATE TABLE referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
    user_id UUID, -- Will link to users table when user signs up
    referral_code VARCHAR(50) NOT NULL,
    signup_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'trial' CHECK (status IN ('trial', 'active', 'canceled')),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Commissions table
CREATE TABLE commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
    referral_id UUID NOT NULL REFERENCES referrals(id) ON DELETE CASCADE,
    subscription_id VARCHAR(255), -- Stripe subscription ID
    amount DECIMAL(10,2) NOT NULL,
    commission_amount DECIMAL(10,2) NOT NULL,
    commission_rate DECIMAL(5,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- Partner sessions (for dashboard login)
CREATE TABLE partner_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partners(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_partners_email ON partners(email);
CREATE INDEX idx_partners_referral_code ON partners(referral_code);
CREATE INDEX idx_partners_status ON partners(status);
CREATE INDEX idx_referrals_partner_id ON referrals(partner_id);
CREATE INDEX idx_referrals_referral_code ON referrals(referral_code);
CREATE INDEX idx_referrals_status ON referrals(status);
CREATE INDEX idx_commissions_partner_id ON commissions(partner_id);
CREATE INDEX idx_commissions_status ON commissions(status);

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code(name VARCHAR(255))
RETURNS VARCHAR(50) AS $$
DECLARE
    base_name VARCHAR(50);
    random_suffix VARCHAR(10);
    referral_code VARCHAR(50);
    attempts INTEGER := 0;
    max_attempts INTEGER := 10;
BEGIN
    -- Extract first part of name and normalize
    base_name := LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]', '', 'g'));
    base_name := LEFT(base_name, 8);
    
    LOOP
        -- Generate random suffix
        random_suffix := LOWER(substring(md5(random()::text), 1, 4));
        referral_code := base_name || '_' || random_suffix;
        
        -- Check if code exists
        IF NOT EXISTS (SELECT 1 FROM partners WHERE referral_code = referral_code) THEN
            RETURN referral_code;
        END IF;
        
        attempts := attempts + 1;
        IF attempts >= max_attempts THEN
            -- Fallback to completely random code
            referral_code := 'partner_' || LOWER(substring(md5(random()::text), 1, 8));
            RETURN referral_code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_partners_updated_at 
    BEFORE UPDATE ON partners 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
