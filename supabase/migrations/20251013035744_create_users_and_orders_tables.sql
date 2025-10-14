/*
  # Create Users and Orders Tables for Order History System

  ## Overview
  This migration creates the core database structure for persistent user order history.
  Orders are linked to user accounts and remain accessible after logout/login.

  ## 1. New Tables
  
  ### `users` table
  - `id` (uuid, primary key) - Unique user identifier
  - `contact` (text, unique, not null) - User's email or phone number for authentication
  - `last_login_at` (timestamptz) - Timestamp of last login
  - `created_at` (timestamptz) - Account creation timestamp
  
  ### `orders` table
  - `id` (uuid, primary key) - Unique order identifier
  - `user_id` (uuid, foreign key) - Links order to user account
  - `order_number` (text, unique, not null) - Human-readable order number (e.g., WC123456789)
  - `customer_name` (text, not null) - Customer's full name
  - `customer_email` (text, not null) - Customer's email address
  - `customer_phone` (text, not null) - Customer's phone number
  - `customer_address` (text, not null) - Complete shipping address
  - `customer_pincode` (text, not null) - 6-digit postal code
  - `items` (jsonb, not null) - Array of order items with product details
  - `subtotal` (decimal, not null) - Order subtotal before shipping
  - `shipping_cost` (decimal, not null) - Calculated shipping cost
  - `total_amount` (decimal, not null) - Final order total
  - `status` (text, not null) - Order status: pending, confirmed, processing, shipped, delivered, cancelled
  - `payment_status` (text, not null) - Payment status: pending, completed, failed
  - `payment_method` (text, not null) - Payment method used
  - `qr_code_data` (text) - UPI QR code data for payment
  - `transaction_id` (text) - Payment transaction reference
  - `estimated_delivery` (timestamptz) - Expected delivery date
  - `created_at` (timestamptz) - Order creation timestamp
  - `updated_at` (timestamptz) - Last update timestamp

  ## 2. Security (Row Level Security)
  
  ### Users Table
  - RLS enabled to protect user data
  - Users can only read their own profile data
  - Users can only update their own profile data
  
  ### Orders Table
  - RLS enabled to protect order data
  - Users can only view their own orders
  - Users can only create orders linked to their account
  - Owner/admin access preserved through separate authentication
  
  ## 3. Important Notes
  - All tables use UUIDs for primary keys for better security and scalability
  - Foreign key constraints ensure data integrity between users and orders
  - Timestamps use `timestamptz` for proper timezone handling
  - Default values ensure data consistency
  - Indexes added for performance on frequently queried columns
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

CREATE POLICY "Users can read own profile"
  ON users FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create own orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());