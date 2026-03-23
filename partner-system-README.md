# 🚀 LeadQualif Partner Referral System

Complete MVP partner referral system built in 2 days with scalable SaaS architecture.

## 📋 Files Created

### 1. Database Schema
- `partner-system-schema.sql` - PostgreSQL schema with all tables and indexes
- Partners, Referrals, Commissions, Sessions tables
- Unique referral code generation
- Performance indexes

### 2. Backend API
- `partner-api-endpoints.js` - Node.js + Express endpoints
- Partner application, referral tracking, Stripe webhooks
- Partner dashboard authentication
- Commission calculation logic

### 3. Frontend Pages
- `partner-application-form.html` - Complete application form
- `partner-dashboard.html` - Real-time partner dashboard
- `partner-admin-panel.html` - Admin management interface

### 4. Documentation
- `partner-system-README.md` - This file

---

## 🏗️ System Architecture

### Database Structure
```sql
partners (id, name, email, company, website, audience_type, audience_size, promotion_strategy, country, referral_code, commission_rate, status, created_at)
referrals (id, partner_id, user_id, referral_code, signup_date, status, ip_address, user_agent, created_at)
commissions (id, partner_id, referral_id, subscription_id, amount, commission_amount, commission_rate, status, created_at, paid_at)
partner_sessions (id, partner_id, token, expires_at, created_at)
```

### API Endpoints
```
POST /api/partners/apply                    # Partner application
GET  /api/referral/track/:code            # Referral tracking
POST /api/auth/signup-with-referral         # User signup with referral
POST /api/webhooks/stripe                # Stripe webhook handler
GET  /api/partner/dashboard              # Partner dashboard data
PUT  /api/admin/partners/:id              # Update partner
POST /api/admin/partners/:id/approve       # Approve partner
POST /api/admin/partners/:id/reject        # Reject partner
GET  /api/admin/partners                  # List all partners
```

---

## 🚀 Quick Start (2-Day Deployment)

### Day 1: Database + Core API

1. **Setup Database**
```bash
# Create database
createdb leadqualif_partners

# Import schema
psql leadqualif_partners < partner-system-schema.sql
```

2. **Install Dependencies**
```bash
npm init -y
npm install express stripe bcryptjs jsonwebtoken uuid crypto
```

3. **Create Server**
```javascript
// server.js - Minimal setup
const express = require('express');
const { applyPartner, trackReferral, stripeWebhook, getPartnerDashboard } = require('./partner-api-endpoints');

const app = express();
app.use(express.json());
app.use(express.static('public'));

// Routes
app.post('/api/partners/apply', applyPartner);
app.get('/api/referral/track/:code', trackReferral);
app.post('/api/webhooks/stripe', stripeWebhook);
app.get('/api/partner/dashboard', authenticatePartner, getPartnerDashboard);

app.listen(3000, () => console.log('Partner system running on port 3000'));
```

### Day 2: Frontend + Integration

1. **Deploy Frontend**
```bash
# Copy HTML files to web directory
cp *.html /var/www/html/
cp partner-system-schema.sql /var/www/html/
```

2. **Configure Environment**
```bash
# .env
STRIPE_WEBHOOK_SECRET=whsec_...
JWT_SECRET=your-jwt-secret
DATABASE_URL=postgresql://user:pass@localhost/leadqualif_partners
```

3. **Test Integration**
- Visit `/partner-application-form.html`
- Submit test application
- Check referral link tracking
- Verify Stripe webhook

---

## 🔧 Core Features

### ✅ Partner Application
- Complete validation
- Unique referral code generation
- Email confirmation
- Status tracking

### ✅ Referral System
- Cookie + localStorage tracking
- IP and user agent logging
- Duplicate prevention
- 30-60 day cookie duration

### ✅ Commission Calculation
- Real-time Stripe webhook processing
- Automatic commission records
- Pending/paid status tracking
- Custom commission rates

### ✅ Partner Dashboard
- Live statistics
- Referral link management
- Commission history
- Monthly/yearly breakdowns

### ✅ Admin Panel
- Partner approval workflow
- Commission rate editing
- Bulk status updates
- Revenue analytics

---

## 🔒 Security Features

### Referral Fraud Prevention
- IP address tracking
- User agent logging
- Duplicate referral detection
- Self-referral prevention

### Authentication
- JWT-based partner login
- Secure session management
- Token expiration handling

### Data Validation
- Input sanitization
- Email format validation
- URL validation
- SQL injection prevention

---

## 📊 Commission Logic

### Standard Rates
```javascript
const commissionRates = {
  affiliate: 0.20,      // 20%
  partner: 0.30,        // 30% (default)
  strategic: 0.25      // 25% + bonuses
};
```

### Calculation Example
```javascript
// Example: €149 subscription × 30% commission
const subscriptionPrice = 149;
const commissionRate = 0.30;
const monthlyCommission = subscriptionPrice * commissionRate; // €44.70

// Annual calculation
const annualRevenue = monthlyCommission * 12; // €536.40
```

### Stripe Webhook Events
- `checkout.session.completed` - Link referral to customer
- `invoice.paid` - Generate commission

---

## 🚀 Scaling Considerations

### Database Optimization
- Indexes on frequently queried columns
- Partitioning by date for large datasets
- Read replicas for dashboard queries

### Performance
- Redis caching for referral lookups
- CDN for static assets
- Database connection pooling

### Monitoring
- Conversion rate tracking
- Commission payment delays
- Partner performance metrics

---

## 🔄 Next Steps (Post-MVP)

### Phase 2 Features
- Automated payouts (Stripe Connect)
- Advanced analytics dashboards
- Multi-level affiliate system
- Marketing asset generator

### Phase 3 Features
- API for partner integration
- White-label options
- Advanced fraud detection
- Mobile partner app

---

## 🛠️ Development Commands

### Database Operations
```bash
# Reset database
psql leadqualif_partners < partner-system-schema.sql

# Check referral codes
SELECT referral_code, status FROM partners WHERE status = 'approved';

# View commissions
SELECT p.name, c.commission_amount, c.created_at 
FROM commissions c 
JOIN partners p ON c.partner_id = p.id 
ORDER BY c.created_at DESC LIMIT 10;
```

### Testing
```bash
# Test referral tracking
curl "http://localhost:3000/api/referral/track/test123"

# Test partner application
curl -X POST http://localhost:3000/api/partners/apply \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Partner","email":"test@example.com","audience_type":"marketing_agency"}'
```

---

## 📞 Support

### Common Issues
1. **Referral not tracking** - Check cookie domain settings
2. **Commission not generating** - Verify Stripe webhook endpoint
3. **Dashboard not loading** - Check JWT token format
4. **Database errors** - Ensure all migrations applied

### Debug Mode
```javascript
// Enable debug logging
process.env.DEBUG = 'true';

// Check referral storage
console.log('Referral cookie:', document.cookie);
console.log('Referral localStorage:', localStorage.getItem('referral'));
```

---

## 🎯 Success Metrics

### MVP KPIs
- Partner applications: 50+ in first month
- Referral conversion: 15%+ signup rate
- Commission accuracy: 99.5%+ automation
- Dashboard engagement: 80%+ monthly active

### Revenue Projections
```javascript
// Conservative estimates (Month 3)
const activePartners = 20;
const avgReferralsPerPartner = 5;
const conversionRate = 0.15;
const avgSubscriptionValue = 149;
const commissionRate = 0.30;

const monthlyRevenue = activePartners * avgReferralsPerPartner * conversionRate * avgSubscriptionValue * commissionRate;
// Result: ~€670 per month, scaling linearly
```

---

## 🏁 Deployment Checklist

- [ ] Database created and migrated
- [ ] Environment variables configured
- [ ] Stripe webhooks configured
- [ ] SSL certificates installed
- [ ] Domain DNS configured
- [ ] Email service connected
- [ ] Monitoring tools setup
- [ ] Backup strategy implemented
- [ ] Load testing completed

---

**Built with ❤️ for LeadQualif Partner Program**
