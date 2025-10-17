# WireBazaar Database Setup & Authorization Guide

## Overview
This document provides complete instructions for setting up authentication and authorization for the WireBazaar e-commerce platform using Supabase.

## Database Architecture

### Tables
1. **profiles** - User profile information
2. **owner_accounts** - Admin/owner accounts with elevated privileges
3. **products** - Product catalog (globally accessible)
4. **orders** - Customer orders (user-isolated)
5. **order_items** - Individual items within orders
6. **addresses** - User shipping addresses
7. **inquiries** - Customer inquiries

## Quick Setup

### Step 1: Apply the Migration
The migration file `20251017000000_complete_auth_and_rls_policies.sql` has been created in `supabase/migrations/`. This migration includes:
- All table structures
- Row Level Security (RLS) policies
- Indexes for performance
- Triggers for updated_at timestamps

Run the migration using Supabase CLI or dashboard.

### Step 2: Create an Owner Account
After applying the migration, create an owner account manually:

```sql
-- First, create the auth user (use Supabase Dashboard Auth section or SQL)
-- Method 1: Using Supabase Dashboard
-- Go to Authentication > Users > Add User
-- Email: owner@yourdomain.com
-- Password: YourSecurePassword123!

-- Method 2: Using SQL (after user is created in auth.users)
-- Replace 'USER_ID_HERE' with the actual UUID from auth.users
INSERT INTO owner_accounts (id, email, full_name, role)
VALUES (
  'USER_ID_HERE',
  'owner@yourdomain.com',
  'Owner Name',
  'admin'
);
```

## Database Queries

### Creating Owner Accounts

```sql
-- Step 1: Get the user ID from auth.users after creating the user
SELECT id, email FROM auth.users WHERE email = 'owner@yourdomain.com';

-- Step 2: Insert into owner_accounts
INSERT INTO owner_accounts (id, email, full_name, role)
VALUES (
  'USER_UUID_FROM_STEP_1',
  'owner@yourdomain.com',
  'Business Owner',
  'admin'
);
```

### Viewing User Data

```sql
-- View all profiles
SELECT * FROM profiles ORDER BY created_at DESC;

-- View all owner accounts
SELECT * FROM owner_accounts;

-- View all orders for a specific user
SELECT o.*,
  (SELECT json_agg(oi.*) FROM order_items oi WHERE oi.order_id = o.id) as items
FROM orders o
WHERE user_id = 'USER_UUID_HERE'
ORDER BY created_at DESC;

-- View all orders (owner view)
SELECT o.*,
  p.email as user_email,
  (SELECT json_agg(oi.*) FROM order_items oi WHERE oi.order_id = o.id) as items
FROM orders o
LEFT JOIN profiles p ON o.user_id = p.id
ORDER BY o.created_at DESC;
```

### Managing Products

```sql
-- View all products
SELECT * FROM products ORDER BY created_at DESC;

-- Add a new product (owner only)
INSERT INTO products (name, description, category, price, image_url, stock_quantity, is_active)
VALUES (
  'Product Name',
  'Product Description',
  'Category Name',
  99.99,
  'https://example.com/image.jpg',
  100,
  true
);

-- Update product stock
UPDATE products
SET stock_quantity = stock_quantity - 5
WHERE id = 'PRODUCT_UUID_HERE';

-- Deactivate product (soft delete)
UPDATE products
SET is_active = false
WHERE id = 'PRODUCT_UUID_HERE';

-- Permanently delete product
DELETE FROM products WHERE id = 'PRODUCT_UUID_HERE';
```

### Order Management

```sql
-- Update order status (owner only)
UPDATE orders
SET status = 'shipped',
    updated_at = NOW()
WHERE id = 'ORDER_UUID_HERE';

-- Update payment status
UPDATE orders
SET payment_status = 'completed',
    transaction_id = 'TXN123456',
    updated_at = NOW()
WHERE id = 'ORDER_UUID_HERE';

-- View orders by status
SELECT o.*, p.email, p.phone
FROM orders o
JOIN profiles p ON o.user_id = p.id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC;
```

### Analytics Queries

```sql
-- Total orders by status
SELECT status, COUNT(*) as count, SUM(total_amount) as total_revenue
FROM orders
GROUP BY status;

-- Top selling products
SELECT
  oi.product_name,
  COUNT(*) as order_count,
  SUM(oi.quantity) as total_quantity,
  SUM(oi.subtotal) as total_revenue
FROM order_items oi
GROUP BY oi.product_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Revenue by date
SELECT
  DATE(created_at) as order_date,
  COUNT(*) as order_count,
  SUM(total_amount) as daily_revenue
FROM orders
WHERE status != 'cancelled'
GROUP BY DATE(created_at)
ORDER BY order_date DESC;
```

## Security Model

### User Isolation
- **Users can ONLY see their own data:**
  - Their own profile
  - Their own orders
  - Their own order items
  - Their own addresses

### Owner Privileges
- **Owners can:**
  - View all orders from all users
  - Update order statuses
  - Manage all products (create, update, delete)
  - View all inquiries
  - Access analytics across all users

### Product Access
- **All authenticated users can:**
  - View active products
  - Search and filter products
- **Only owners can:**
  - Add new products
  - Update product details
  - Delete products
  - View inactive products

## Row Level Security (RLS) Policies

All tables have RLS enabled. Key policies:

### profiles
- Users can view/update only their own profile
- Users can insert their own profile on signup

### orders
- Users can view/create/update only their own orders
- Owners can view/update all orders

### order_items
- Users can view items only from their own orders
- Users can insert items only for their own orders
- Owners can view all order items

### products
- All authenticated users can view active products
- Only owners can create/update/delete products

### owner_accounts
- Only the owner themselves can view their account

## Data Persistence

**IMPORTANT:** No data is automatically deleted!

- All orders persist indefinitely
- All products remain until manually deleted
- User profiles persist until the user deletes their account
- No soft deletes - data is permanent unless explicitly removed

## Authentication Flow

### Customer Authentication
1. Customer enters email/phone on website
2. OTP sent via email or SMS
3. Customer verifies OTP
4. Profile created/updated in `profiles` table
5. Session established

### Owner Authentication
1. Owner enters email and password
2. Credentials verified against Supabase Auth
3. System checks if user exists in `owner_accounts` table
4. If yes, grant owner access
5. If no, deny access (even if valid auth user)

## Testing RLS Policies

```sql
-- Test as regular user (set JWT to regular user)
SELECT * FROM orders; -- Should only see own orders
SELECT * FROM products WHERE is_active = true; -- Should see all active products

-- Test as owner (set JWT to owner user)
SELECT * FROM orders; -- Should see ALL orders
SELECT * FROM products; -- Should see ALL products (active and inactive)
```

## Troubleshooting

### Issue: Cannot see orders after placing them
**Solution:** Ensure the user_id in the order matches auth.uid()

```sql
-- Verify user ID
SELECT auth.uid();

-- Check if orders exist
SELECT * FROM orders WHERE user_id = auth.uid();
```

### Issue: Owner cannot login
**Solution:** Ensure the owner account exists in owner_accounts

```sql
-- Check if owner account exists
SELECT * FROM owner_accounts WHERE email = 'owner@yourdomain.com';

-- If not, create it (using the auth user's ID)
INSERT INTO owner_accounts (id, email, full_name, role)
SELECT id, email, 'Owner Name', 'admin'
FROM auth.users
WHERE email = 'owner@yourdomain.com';
```

### Issue: Products not showing for users
**Solution:** Ensure products are marked as active

```sql
-- Check product status
SELECT id, name, is_active FROM products;

-- Activate products
UPDATE products SET is_active = true WHERE id = 'PRODUCT_UUID_HERE';
```

## Backup Recommendations

Regular backups are essential:
- Use Supabase's built-in backup features
- Export data regularly using SQL dumps
- Keep migration history for recreating schema

## Security Best Practices

1. **Never expose service role keys** - Use anon key in frontend
2. **Always use RLS policies** - Never disable RLS on tables
3. **Validate user input** - Use check constraints and validation
4. **Regular audits** - Review access logs periodically
5. **Secure owner credentials** - Use strong passwords and 2FA
6. **Monitor for suspicious activity** - Check for unusual query patterns

## Support

For issues or questions:
1. Check Supabase logs in Dashboard
2. Review RLS policies
3. Verify authentication state
4. Test queries in SQL Editor

---

**Last Updated:** 2025-10-17
**Version:** 1.0
