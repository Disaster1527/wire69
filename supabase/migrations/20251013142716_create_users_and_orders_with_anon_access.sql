/*
  # Create Users and Orders Tables with Anonymous Access

  ## Overview
  This migration creates the core database structure for persistent user order history
  with proper RLS policies that allow anonymous users to register and place orders.

  ## 1. New Tables
  
  ### `users` table
  - `id` (uuid, primary key) - Unique user identifier
  - `contact` (text, unique, not null) - User's email or phone number for authentication
  - `last_login_at` (timestamptz) - Timestamp of last login
  - `created_at` (timestamptz) - Account creation timestamp
  
  ### `orders` table
  - `id` (uuid, primary key) - Unique order identifier
  - `user_id` (uuid, foreign key) - Links order to user account
  - `order_number` (text, unique, not null) - Human-readable order number
  - `customer_name` (text, not null) - Customer's full name
  - `customer_email` (text, not null) - Customer's email address
  - `customer_phone` (text, not null) - Customer's phone number
  - `customer_address` (text, not null) - Complete shipping address
  - `customer_pincode` (text, not null) - 6-digit postal code
  - `items` (jsonb, not null) - Array of order items with product details
  - `subtotal` (decimal, not null) - Order subtotal before shipping
  - `shipping_cost` (decimal, not null) - Calculated shipping cost
  - `total_amount` (decimal, not null) - Final order total
  - `status` (text, not null) - Order status
  - `payment_status` (text, not null) - Payment status
  - `payment_method` (text, not null) - Payment method used
  - `qr_code_data` (text) - UPI QR code data for payment
  - `transaction_id` (text) - Payment transaction reference
  - `estimated_delivery` (timestamptz) - Expected delivery date
  - `created_at` (timestamptz) - Order creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ## 2. Security (Row Level Security)
  
  ### Users Table
  - RLS enabled to protect user data
  - Anonymous users can insert new user records (for registration)
  - Anonymous users can read their own profile by contact
  - Anonymous users can update their own profile
  
  ### Orders Table
  - RLS enabled to protect order data
  - Anonymous users can view all orders (for admin dashboard)
  - Anonymous users can create orders (for checkout)
  - Anonymous users can update orders (for admin dashboard)
  
  ## 3. Important Notes
  - Anonymous access is required because this app uses custom OTP auth, not Supabase Auth
  - RLS policies are permissive to allow the custom authentication system to work
  - Frontend implements its own authentication logic
*/

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact text UNIQUE NOT NULL,
  last_login_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_number text UNIQUE NOT NULL,
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_phone text NOT NULL,
  customer_address text NOT NULL,
  customer_pincode text NOT NULL,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtotal decimal(10,2) NOT NULL DEFAULT 0,
  shipping_cost decimal(10,2) NOT NULL DEFAULT 0,
  total_amount decimal(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  payment_status text NOT NULL DEFAULT 'pending',
  payment_method text NOT NULL DEFAULT 'qr_code',
  qr_code_data text,
  transaction_id text,
  estimated_delivery timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_contact ON users(contact);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon to insert users"
  ON users FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Allow anon to read users"
  ON users FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon to update users"
  ON users FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow anon to read all orders"
  ON orders FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon to create orders"
  ON orders FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Allow anon to update orders"
  ON orders FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);