// ========================================
// LEADQUALIF PARTNER API ENDPOINTS
// Node.js + Express Backend Logic
// ========================================

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

// Database helpers (adapt to your DB)
const db = require('./database');

// ========================================
// PARTNER APPLICATION
// ========================================

// POST /api/partners/apply
exports.applyPartner = async (req, res) => {
  try {
    const {
      name,
      email,
      company,
      website,
      audience_type,
      audience_size,
      promotion_strategy,
      country
    } = req.body;

    // Validation
    if (!name || !email || !audience_type) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if partner already exists
    const existingPartner = await db.query(
      'SELECT id FROM partners WHERE email = $1',
      [email]
    );

    if (existingPartner.rows.length > 0) {
      return res.status(409).json({ error: 'Partner already exists' });
    }

    // Generate unique referral code
    const referralCode = await generateReferralCode(name);

    // Create partner
    const result = await db.query(
      `INSERT INTO partners (name, email, company, website, audience_type, audience_size, promotion_strategy, country, referral_code)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, referral_code, created_at`,
      [name, email, company, website, audience_type, audience_size, promotion_strategy, country, referralCode]
    );

    const partner = result.rows[0];

    // Send confirmation email
    await sendPartnerConfirmationEmail(email, partner.referral_code);

    res.status(201).json({
      success: true,
      partner: {
        id: partner.id,
        referral_code: partner.referral_code,
        status: 'pending',
        created_at: partner.created_at
      }
    });

  } catch (error) {
    console.error('Partner application error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// ========================================
// REFERRAL TRACKING
// ========================================

// GET /api/referral/track/:code
exports.trackReferral = async (req, res) => {
  try {
    const { code } = req.params;
    const { ip, userAgent } = req;

    if (!code) {
      return res.status(400).json({ error: 'Referral code required' });
    }

    // Verify partner exists and is approved
    const partner = await db.query(
      'SELECT id, name FROM partners WHERE referral_code = $1 AND status = $2',
      [code, 'approved']
    );

    if (partner.rows.length === 0) {
      return res.status(404).json({ error: 'Invalid referral code' });
    }

    // Create referral record (if not exists for this session)
    const referralId = uuidv4();
    await db.query(
      `INSERT INTO referrals (id, partner_id, referral_code, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT DO NOTHING`,
      [referralId, partner.rows[0].id, code, ip, userAgent]
    );

    // Set referral cookie (30 days)
    res.cookie('leadqualif_referral', code, {
      maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax'
    });

    // Store in localStorage fallback
    res.json({
      success: true,
      referral: {
        partner_name: partner.rows[0].name,
        referral_code: code,
        referral_id: referralId
      }
    });

  } catch (error) {
    console.error('Referral tracking error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// ========================================
// USER SIGNUP WITH REFERRAL
// ========================================

// POST /api/auth/signup-with-referral
exports.signupWithReferral = async (req, res) => {
  try {
    const { email, password, name, company } = req.body;
    const referralCode = req.cookies.leadqualif_referral || req.body.referral_code;

    // Create user (your existing user creation logic)
    const user = await createUser({ email, password, name, company });

    // If referral exists, link it
    if (referralCode) {
      const referral = await db.query(
        'UPDATE referrals SET user_id = $1, signup_date = NOW() WHERE referral_code = $2 AND user_id IS NULL RETURNING id, partner_id',
        [user.id, referralCode]
      );

      if (referral.rows.length > 0) {
        // Store referral in user session for later commission tracking
        req.session.referral_id = referral.rows[0].id;
        req.session.partner_id = referral.rows[0].partner_id;
      }
    }

    res.status(201).json({
      success: true,
      user: { id: user.id, email: user.email },
      referral: referralCode ? { linked: true } : { linked: false }
    });

  } catch (error) {
    console.error('Signup with referral error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// ========================================
// STRIPE WEBHOOK HANDLER
// ========================================

// POST /api/webhooks/stripe
exports.stripeWebhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
  } catch (err) {
    console.log(`Webhook signature verification failed.`, err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  switch (event.type) {
    case 'checkout.session.completed':
      await handleCheckoutCompleted(event.data.object);
      break;

    case 'invoice.paid':
      await handleInvoicePaid(event.data.object);
      break;

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  // Return a 200 response to acknowledge receipt of the event
  res.json({ received: true });
};

// ========================================
// WEBHOOK HANDLERS
// ========================================

async function handleCheckoutCompleted(checkoutSession) {
  try {
    const { customer_email, metadata } = checkoutSession;
    const { referral_code } = metadata || {};

    if (!referral_code) return;

    // Find user by email
    const user = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [customer_email]
    );

    if (user.rows.length === 0) return;

    // Find and update referral
    const referral = await db.query(
      'UPDATE referrals SET user_id = $1 WHERE referral_code = $2 AND user_id IS NULL RETURNING id, partner_id',
      [user.rows[0].id, referral_code]
    );

    if (referral.rows.length > 0) {
      // Store referral info for commission tracking
      await db.query(
        'INSERT INTO user_referrals (user_id, referral_id, partner_id) VALUES ($1, $2, $3)',
        [user.rows[0].id, referral.rows[0].id, referral.rows[0].partner_id]
      );
    }

  } catch (error) {
    console.error('Checkout completed webhook error:', error);
  }
}

async function handleInvoicePaid(invoice) {
  try {
    const { customer, subscription, lines } = invoice;
    const subscriptionId = subscription.id;
    const amount = invoice.total / 100; // Convert from cents

    // Find user's referral
    const userReferral = await db.query(
      `SELECT ur.referral_id, ur.partner_id, ur.user_id 
       FROM user_referrals ur
       JOIN users u ON ur.user_id = u.id
       WHERE u.stripe_customer_id = $1`,
      [customer]
    );

    if (userReferral.rows.length === 0) return;

    const { referral_id, partner_id } = userReferral.rows[0];

    // Get partner commission rate
    const partner = await db.query(
      'SELECT commission_rate FROM partners WHERE id = $1',
      [partner_id]
    );

    if (partner.rows.length === 0) return;

    const commissionRate = partner.rows[0].commission_rate;
    const commissionAmount = amount * commissionRate;

    // Create commission record
    await db.query(
      `INSERT INTO commissions (partner_id, referral_id, subscription_id, amount, commission_amount, commission_rate, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')`,
      [partner_id, referral_id, subscriptionId, amount, commissionAmount, commissionRate]
    );

    console.log(`Commission created: ${commissionAmount}€ for partner ${partner_id}`);

  } catch (error) {
    console.error('Invoice paid webhook error:', error);
  }
}

// ========================================
// PARTNER DASHBOARD
// ========================================

// GET /api/partner/dashboard
exports.getPartnerDashboard = async (req, res) => {
  try {
    const { partner_id } = req.partner; // Set by auth middleware

    // Get partner info
    const partner = await db.query(
      'SELECT * FROM partners WHERE id = $1',
      [partner_id]
    );

    if (partner.rows.length === 0) {
      return res.status(404).json({ error: 'Partner not found' });
    }

    // Get referral stats
    const referralStats = await db.query(
      `SELECT 
         COUNT(*) as total_referrals,
         COUNT(CASE WHEN status = 'active' THEN 1 END) as active_subscriptions,
         COUNT(CASE WHEN status = 'trial' THEN 1 END) as trial_users
       FROM referrals 
       WHERE partner_id = $1`,
      [partner_id]
    );

    // Get commission stats
    const commissionStats = await db.query(
      `SELECT 
         SUM(CASE WHEN status = 'paid' THEN commission_amount ELSE 0 END) as total_paid,
         SUM(CASE WHEN status = 'pending' THEN commission_amount ELSE 0 END) as total_pending,
         SUM(CASE WHEN created_at >= date_trunc('month', NOW()) THEN commission_amount ELSE 0 END) as monthly_earnings
       FROM commissions 
       WHERE partner_id = $1`,
      [partner_id]
    );

    // Get recent referrals
    const recentReferrals = await db.query(
      `SELECT r.*, u.email as user_email, u.company as user_company
       FROM referrals r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.partner_id = $1
       ORDER BY r.created_at DESC
       LIMIT 10`,
      [partner_id]
    );

    const stats = {
      ...referralStats.rows[0],
      ...commissionStats.rows[0],
      monthly_earnings: parseFloat(commissionStats.rows[0].monthly_earnings) || 0,
      total_paid: parseFloat(commissionStats.rows[0].total_paid) || 0,
      total_pending: parseFloat(commissionStats.rows[0].total_pending) || 0
    };

    res.json({
      success: true,
      partner: partner.rows[0],
      stats,
      recent_referrals: recentReferrals.rows
    });

  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

// ========================================
// UTILITY FUNCTIONS
// ========================================

async function generateReferralCode(name) {
  const baseName = name.toLowerCase().replace(/[^a-z0-9]/g, '').substring(0, 8);
  const randomSuffix = crypto.randomBytes(2).toString('hex');
  const referralCode = `${baseName}_${randomSuffix}`;
  
  // Check uniqueness
  const existing = await db.query(
    'SELECT id FROM partners WHERE referral_code = $1',
    [referralCode]
  );
  
  if (existing.rows.length === 0) {
    return referralCode;
  }
  
  // Fallback to random
  return `partner_${crypto.randomBytes(4).toString('hex')}`;
}

async function sendPartnerConfirmationEmail(email, referralCode) {
  // Implement your email service
  console.log(`Partner confirmation email sent to ${email} with code ${referralCode}`);
}

// ========================================
// AUTH MIDDLEWARE
// ========================================

exports.authenticatePartner = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const partner = await db.query(
      'SELECT id FROM partners WHERE id = $1',
      [decoded.partner_id]
    );

    if (partner.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    req.partner = { partner_id: decoded.partner_id };
    next();

  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};
