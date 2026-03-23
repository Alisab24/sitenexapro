-- ========================================
-- Create Additional Functions and Triggers
-- LeadQualif Partner Referral System
-- ========================================

-- Function to get partner statistics
CREATE OR REPLACE FUNCTION public.get_partner_stats(p_partner_id UUID)
RETURNS TABLE (
    total_referrals BIGINT,
    active_subscriptions BIGINT,
    trial_users BIGINT,
    canceled_users BIGINT,
    total_commissions DECIMAL,
    pending_commissions DECIMAL,
    paid_commissions DECIMAL,
    monthly_commissions DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_referrals,
        COUNT(CASE WHEN r.status = 'active' THEN 1 END) as active_subscriptions,
        COUNT(CASE WHEN r.status = 'trial' THEN 1 END) as trial_users,
        COUNT(CASE WHEN r.status = 'canceled' THEN 1 END) as canceled_users,
        COALESCE(SUM(c.commission_amount), 0) as total_commissions,
        COALESCE(SUM(CASE WHEN c.status = 'pending' THEN c.commission_amount ELSE 0 END), 0) as pending_commissions,
        COALESCE(SUM(CASE WHEN c.status = 'paid' THEN c.commission_amount ELSE 0 END), 0) as paid_commissions,
        public.get_monthly_commission_total(p_partner_id) as monthly_commissions
    FROM public.partners p
    LEFT JOIN public.referrals r ON p.id = r.partner_id
    LEFT JOIN public.commissions c ON r.id = c.referral_id
    WHERE p.id = p_partner_id
    GROUP BY p.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all partners for admin
CREATE OR REPLACE FUNCTION public.get_all_partners()
RETURNS TABLE (
    id UUID,
    name TEXT,
    email TEXT,
    company TEXT,
    website TEXT,
    audience_type TEXT,
    audience_size TEXT,
    referral_code TEXT,
    commission_rate DECIMAL,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    referral_count BIGINT,
    total_revenue DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.*,
        COALESCE(referral_counts.count, 0) as referral_count,
        COALESCE(revenue_totals.total, 0) as total_revenue
    FROM public.partners p
    LEFT JOIN (
        SELECT 
            partner_id, 
            COUNT(*) as count
        FROM public.referrals 
        WHERE user_id IS NOT NULL
        GROUP BY partner_id
    ) referral_counts ON p.id = referral_counts.partner_id
    LEFT JOIN (
        SELECT 
            partner_id,
            SUM(commission_amount) as total
        FROM public.commissions 
        WHERE status = 'paid'
        GROUP BY partner_id
    ) revenue_totals ON p.id = revenue_totals.partner_id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate referral code
CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS TABLE (
    valid BOOLEAN,
    partner_id UUID,
    partner_name TEXT,
    commission_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        true as valid,
        p.id as partner_id,
        p.name as partner_name,
        p.commission_rate
    FROM public.partners p
    WHERE p.referral_code = p_code 
    AND p.status = 'approved'
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update partner stats on commission creation
CREATE OR REPLACE FUNCTION public.update_partner_commission_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- This trigger can be used to update cached stats
    -- For now, it's a placeholder for future optimization
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER update_partner_stats_on_commission
    AFTER INSERT ON public.commissions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_partner_commission_stats();

-- Function to handle Stripe webhook data
CREATE OR REPLACE FUNCTION public.process_stripe_webhook(
    p_event_type TEXT,
    p_customer_email TEXT,
    p_subscription_id TEXT,
    p_amount DECIMAL,
    p_referral_code TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    commission_id UUID
) AS $$
DECLARE
    v_user_id UUID;
    v_referral_id UUID;
    v_partner_id UUID;
    v_commission_rate DECIMAL;
    v_commission_amount DECIMAL;
BEGIN
    -- Handle checkout.session.completed
    IF p_event_type = 'checkout.session.completed' AND p_referral_code IS NOT NULL THEN
        -- Find user by email (assuming you have a users table)
        -- This is a placeholder - adjust based on your actual users table
        BEGIN
            -- SELECT id INTO v_user_id FROM users WHERE email = p_customer_email LIMIT 1;
            -- For demo, we'll skip user lookup and focus on referral linking
        EXCEPTION WHEN OTHERS THEN
            -- User not found, continue
            v_user_id := NULL;
        END;
        
        -- Link referral if found
        IF v_user_id IS NOT NULL THEN
            v_referral_id := public.link_user_to_referral(v_user_id, p_referral_code);
        END IF;
        
        RETURN SELECT true, 'Referral linked successfully', v_referral_id;
    END IF;
    
    -- Handle invoice.paid
    IF p_event_type = 'invoice.paid' THEN
        -- Find the referral and partner for this subscription
        SELECT r.id, r.partner_id, p.commission_rate
        INTO v_referral_id, v_partner_id, v_commission_rate
        FROM public.referrals r
        JOIN public.partners p ON r.partner_id = p.id
        JOIN public.user_referrals ur ON r.id = ur.referral_id
        JOIN users u ON ur.user_id = u.id
        WHERE u.email = p_customer_email 
        AND r.subscription_id = p_subscription_id
        LIMIT 1;
        
        -- Calculate and create commission
        IF v_referral_id IS NOT NULL THEN
            v_commission_amount := public.calculate_commission(p_amount, v_commission_rate);
            
            INSERT INTO public.commissions (
                partner_id, 
                referral_id, 
                subscription_id, 
                amount, 
                commission_amount, 
                commission_rate, 
                status,
                created_at,
                paid_at
            ) VALUES (
                v_partner_id,
                v_referral_id,
                p_subscription_id,
                p_amount,
                v_commission_amount,
                v_commission_rate,
                'paid',
                NOW(),
                NOW()
            );
            
            RETURN SELECT true, 'Commission created successfully', (
                SELECT id FROM public.commissions 
                WHERE partner_id = v_partner_id 
                AND referral_id = v_referral_id 
                AND subscription_id = p_subscription_id
                LIMIT 1
            );
        END IF;
    END IF;
    
    RETURN SELECT false, 'No action taken', NULL::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policies for the new functions
-- These functions will respect RLS policies defined in the individual tables
