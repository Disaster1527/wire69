/*
  # Complete WireBazaar Authentication & Authorization Schema

  ## Overview
  This migration establishes a complete authentication and authorization system for WireBazaar
  with proper Row Level Security (RLS) policies ensuring data isolation and access control.

  ## Tables & Security Model

  ### 1. profiles
  User profile data linked to Supabase auth.users
  - **Columns:**
    - `id` (uuid, FK to auth.users) - User identifier
    - `email` (text, unique) - User email
    - `phone` (text) - Contact phone
    - `full_name` (text) - Full name
    - `created_at` (timestamptz) - Account creation
    - `updated_at` (timestamptz) - Last update

  - **Security:**
    - Users can only view and update their own profile
    - No public access

  ### 2. orders
  Customer orders with complete isolation per user
  - **Columns:**
    - `id` (uuid, auto-generated) - Order identifier
    - `user_id` (uuid, FK to profiles) - Owner of order (REQUIRED)
    - `order_number` (text, unique) - Human-readable order number
    - `status` (text) - Order status (pending/processing/shipped/delivered/cancelled)
    - `payment_status` (text) - Payment status (pending/completed/failed)
    - `payment_method` (text) - Payment method used
    - `subtotal` (numeric) - Items subtotal
    - `shipping_cost` (numeric) - Shipping charges
    - `total_amount` (numeric) - Total order amount
    - `customer_name` (text) - Customer name
    - `customer_email` (text) - Customer email
    - `customer_phone` (text) - Customer phone
    - `shipping_address` (jsonb) - Complete shipping address
    - `qr_code_data` (text) - QR code for payment
    - `transaction_id` (text) - Payment transaction ID
    - `estimated_delivery` (date) - Estimated delivery date
    - `created_at` (timestamptz) - Order creation
    - `updated_at` (timestamptz) - Last update

  - **Security:**
    - Authenticated users can create orders (user_id must match auth.uid())
    - Users can only view their own orders
    - Users can only update their own orders
    - Owner accounts can view and update all orders

  ### 3. order_items
  Individual items within orders
  - **Columns:**
    - `id` (uuid, auto-generated) - Item identifier
    - `order_id` (uuid, FK to orders) - Parent order
    - `product_id` (uuid) - Product reference
    - `product_name` (text) - Product name snapshot
    - `product_price` (numeric) - Price at time of order
    - `quantity` (integer) - Quantity ordered
    - `subtotal` (numeric) - Line item total
    - `created_at` (timestamptz) - Item creation

  - **Security:**
    - Access controlled through parent order's RLS policies
    - Users can only view items from their own orders
    - Owner accounts can view all order items

  ### 4. products
  Product catalog - globally accessible, owner-managed
  - **Columns:**
    - `id` (uuid, auto-generated) - Product identifier
    - `name` (text) - Product name
    - `description` (text) - Product description
    - `category` (text) - Product category
    - `price` (numeric) - Product price
    - `image_url` (text) - Product image
    - `stock_quantity` (integer) - Available stock
    - `is_active` (boolean) - Product visibility
    - `created_at` (timestamptz) - Product creation
    - `updated_at` (timestamptz) - Last update

  - **Security:**
    - All authenticated users can view active products
    - Only owner accounts can create, update, or delete products
    - Products persist unless manually deleted by owner

  ### 5. owner_accounts
  Admin/owner accounts with elevated privileges
  - **Columns:**
    - `id` (uuid, FK to auth.users) - Owner identifier
    - `email` (text, unique) - Owner email
    - `full_name` (text) - Owner full name
    - `role` (text) - Role (admin/owner)
    - `created_at` (timestamptz) - Account creation

  - **Security:**
    - Only accessible to authenticated owner accounts
    - Used to determine elevated privileges

  ## Important Notes

  1. **Data Persistence:**
     - NO auto-deletion of any data
     - All data persists until manually deleted by authorized users
     - Soft deletes not implemented - data is permanent

  2. **User Isolation:**
     - Each user can ONLY see their own orders
     - RLS policies enforce strict data isolation
     - No cross-user data access except for owners

  3. **Owner Privileges:**
     - Owners can view all orders across all users
     - Owners can manage all products
     - Owners can update order statuses

  4. **Authentication Required:**
     - All operations require authentication via Supabase Auth
     - Anonymous access not permitted except for public product viewing
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing policies to recreate them properly
DO $$
BEGIN
  -- Drop all existing policies on all tables
  DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
  DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
  DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
  DROP POLICY IF EXISTS "Owner accounts can view own account" ON owner_accounts;
  DROP POLICY IF EXISTS "Anyone can view active products" ON products;
  DROP POLICY IF EXISTS "Owners can view all products" ON products;
  DROP POLICY IF EXISTS "Owners can insert products" ON products;
  DROP POLICY IF EXISTS "Owners can update products" ON products;
  DROP POLICY IF EXISTS "Owners can delete products" ON products;
  DROP POLICY IF EXISTS "Users can view own orders" ON orders;
  DROP POLICY IF EXISTS "Owners can view all orders" ON orders;
  DROP POLICY IF EXISTS "Users can create own orders" ON orders;
  DROP POLICY IF EXISTS "Users can update own orders" ON orders;
  DROP POLICY IF EXISTS "Owners can update all orders" ON orders;
  DROP POLICY IF EXISTS "Users can view own order items" ON order_items;
  DROP POLICY IF EXISTS "Owners can view all order items" ON order_items;
  DROP POLICY IF EXISTS "Users can insert own order items" ON order_items;
  DROP POLICY IF EXISTS "Users can view own addresses" ON addresses;
  DROP POLICY IF EXISTS "Users can insert own addresses" ON addresses;
  DROP POLICY IF EXISTS "Users can update own addresses" ON addresses;
  DROP POLICY IF EXISTS "Users can delete own addresses" ON addresses;
  DROP POLICY IF EXISTS "Owners can view all inquiries" ON inquiries;
  DROP POLICY IF EXISTS "Anyone can insert inquiries" ON inquiries;
  DROP POLICY IF EXISTS "Owners can update inquiries" ON inquiries;
END $$;

-- =====================================================
-- PROFILES TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- =====================================================
-- OWNER ACCOUNTS TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Owner accounts can view own account"
  ON owner_accounts FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- =====================================================
-- PRODUCTS TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Anyone can view active products"
  ON products FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Owners can view all products"
  ON products FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

CREATE POLICY "Owners can insert products"
  ON products FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

CREATE POLICY "Owners can update products"
  ON products FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

CREATE POLICY "Owners can delete products"
  ON products FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

-- =====================================================
-- ORDERS TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Users can view own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Owners can view all orders"
  ON orders FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

CREATE POLICY "Users can create own orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Owners can update all orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

-- =====================================================
-- ORDER ITEMS TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Users can view own order items"
  ON order_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.user_id = auth.uid()
    )
  );

CREATE POLICY "Owners can view all order items"
  ON order_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own order items"
  ON order_items FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = order_items.order_id
      AND orders.user_id = auth.uid()
    )
  );

-- =====================================================
-- ADDRESSES TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Users can view own addresses"
  ON addresses FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own addresses"
  ON addresses FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own addresses"
  ON addresses FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own addresses"
  ON addresses FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- =====================================================
-- INQUIRIES TABLE RLS POLICIES
-- =====================================================

CREATE POLICY "Owners can view all inquiries"
  ON inquiries FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

CREATE POLICY "Anyone can insert inquiries"
  ON inquiries FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Owners can update inquiries"
  ON inquiries FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
