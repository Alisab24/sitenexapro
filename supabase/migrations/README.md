# 🚀 Supabase Migrations - LeadQualif Partner System

Complete set of Supabase migrations for the partner referral system.

## 📋 Migration Files

### **001_create_partners_table.sql**
- Partners table with RLS
- Auto-referral code generation
- Commission rate management
- Status tracking (pending/approved/rejected)

### **002_create_referrals_table.sql**
- Referrals tracking table
- IP + user agent logging
- Duplicate prevention
- Status tracking (trial/active/canceled)

### **003_create_commissions_table.sql**
- Commissions table with financial tracking
- Pending/paid status management
- Monthly commission calculations
- Stripe subscription linking

### **004_create_partner_sessions_table.sql**
- Partner authentication sessions
- Token management
- Auto-expiration cleanup
- Secure session handling

### **005_create_user_referrals_link.sql**
- Links users to referrals
- Prevents duplicate linking
- Referral attribution tracking
- User-referral relationship management

### **006_create_functions_and_triggers.sql**
- Advanced SQL functions
- Partner statistics
- Referral validation
- Stripe webhook processing
- Performance optimization

---

## 🚀 Deployment Instructions

### **Step 1: Create Supabase Project**
1. Go to [supabase.com](https://supabase.com)
2. Create new project: `leadqualif-partners`
3. Note your project URL and anon key

### **Step 2: Run Migrations**

#### **Option A: Supabase Dashboard**
```bash
# Upload each file individually in the Supabase SQL Editor
# Order: 001 → 002 → 003 → 004 → 005 → 006
```

#### **Option B: Supabase CLI**
```bash
# Install Supabase CLI
npm install -g supabase

# Login to your project
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Run migrations
supabase db push
```

#### **Option C: Direct SQL**
```bash
# Using psql with your Supabase connection string
psql "postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres" < 001_create_partners_table.sql
psql "postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres" < 002_create_referrals_table.sql
# ... continue for all files
```

### **Step 3: Configure Row Level Security (RLS)**

After running migrations, you need to set up authentication:

```sql
-- Create a service role for admin access
INSERT INTO auth.users (id, email, role)
VALUES (
    gen_random_uuid(),
    'service@leadqualif.com',
    'service_role'
);

-- Enable RLS for all tables (already included in migrations)
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_referrals ENABLE ROW LEVEL SECURITY;
```

### **Step 4: Create API Keys**

In Supabase Dashboard:
1. Go to Settings → API
2. Create new API key with `service_role` permissions
3. Note your `anon key` and `service_role key`

---

## 🔧 Key Features Implemented

### **Security**
- ✅ Row Level Security (RLS) on all tables
- ✅ Partner self-access only
- ✅ Service role for admin operations
- ✅ IP-based duplicate prevention
- ✅ Token-based authentication

### **Performance**
- ✅ Optimized indexes on all foreign keys
- ✅ Composite indexes for common queries
- ✅ Functions for complex calculations
- ✅ Triggers for data consistency

### **Data Integrity**
- ✅ Unique constraints on critical fields
- ✅ Foreign key cascading deletes
- ✅ Check constraints for valid values
- ✅ Prevent duplicate user-referral links

### **Business Logic**
- ✅ Automatic referral code generation
- ✅ Commission calculation functions
- ✅ Monthly/annual aggregation
- ✅ Partner statistics functions

---

## 📊 Database Schema Overview

```sql
partners (id, name, email, company, website, audience_type, audience_size, promotion_strategy, country, referral_code, commission_rate, status, created_at, updated_at)
referrals (id, partner_id, user_id, referral_code, signup_date, status, ip_address, user_agent, created_at)
commissions (id, partner_id, referral_id, subscription_id, amount, commission_amount, commission_rate, status, created_at, paid_at)
partner_sessions (id, partner_id, token, expires_at, created_at)
user_referrals (id, user_id, referral_id, partner_id, created_at, UNIQUE(user_id, referral_id))
```

---

## 🔍 Testing the Setup

### **Test Referral Code Generation**
```sql
SELECT public.generate_referral_code('Test Partner');
-- Expected: test_82xk (or similar)
```

### **Test Partner Statistics**
```sql
SELECT * FROM public.get_partner_stats('YOUR-PARTNER-UUID');
-- Returns all partner metrics
```

### **Test Referral Validation**
```sql
SELECT * FROM public.validate_referral_code('test_82xk');
-- Returns partner info if valid
```

### **Test Stripe Webhook Processing**
```sql
SELECT * FROM public.process_stripe_webhook(
    'invoice.paid',
    'customer@example.com',
    'sub_123456',
    149.00,
    'test_82xk'
);
-- Creates commission record
```

---

## 🚀 Production Considerations

### **Connection Pooling**
```javascript
// In your Node.js backend
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10, // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### **Environment Variables**
```bash
# .env
DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
SUPABASE_SERVICE_KEY=[YOUR-SERVICE-KEY]
SUPABASE_ANON_KEY=[YOUR-ANON-KEY]
JWT_SECRET=[YOUR-JWT-SECRET]
STRIPE_WEBHOOK_SECRET=[STRIPE-WEBHOOK-SECRET]
```

### **Monitoring**
```sql
-- Monitor table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname::text, tablename::text)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname::text, tablename::text) DESC;

-- Monitor slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
WHERE mean_time > 100 
ORDER BY mean_time DESC 
LIMIT 10;
```

---

## 🔧 Common Operations

### **Partner Management**
```sql
-- Approve partner
UPDATE public.partners 
SET status = 'approved' 
WHERE id = 'PARTNER-UUID';

-- Update commission rate
UPDATE public.partners 
SET commission_rate = 0.25 
WHERE id = 'PARTNER-UUID';

-- Get pending partners
SELECT * FROM public.partners 
WHERE status = 'pending' 
ORDER BY created_at;
```

### **Commission Management**
```sql
-- Get pending commissions
SELECT * FROM public.commissions 
WHERE status = 'pending';

-- Mark commissions as paid
UPDATE public.commissions 
SET status = 'paid', paid_at = NOW() 
WHERE id IN ('COMMISSION-ID-1', 'COMMISSION-ID-2');

-- Monthly commission report
SELECT 
    p.name,
    p.email,
    SUM(c.commission_amount) as monthly_total
FROM public.commissions c
JOIN public.partners p ON c.partner_id = p.id
WHERE c.status = 'paid' 
AND c.created_at >= date_trunc('month', NOW())
AND c.created_at < date_trunc('month', NOW()) + INTERVAL '1 month'
GROUP BY p.id, p.name, p.email;
```

---

## 🚨 Troubleshooting

### **Common Issues**
1. **RLS blocking access** - Check auth.uid() matches user ID
2. **Migration failures** - Run migrations in order
3. **Function not found** - Ensure all migrations completed
4. **Permission denied** - Check service role setup

### **Debug Queries**
```sql
-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public';

-- Check function existence
SELECT proname FROM pg_proc WHERE proname = 'generate_referral_code';

-- Test referral code uniqueness
SELECT referral_code, COUNT(*) 
FROM public.partners 
GROUP BY referral_code 
HAVING COUNT(*) > 1;
```

---

## 📈 Next Steps

After running these migrations:

1. **Test all functions** in Supabase SQL Editor
2. **Set up authentication** with proper JWT handling
3. **Configure API endpoints** to use these SQL functions
4. **Implement webhook handlers** for Stripe integration
5. **Set up monitoring** for production deployment

The database is now ready for the complete partner referral system! 🎯
