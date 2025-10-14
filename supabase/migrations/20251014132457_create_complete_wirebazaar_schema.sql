/*
  # WireBazaar Complete Database Schema

  ## Overview
  This migration creates a complete e-commerce database schema for WireBazaar with authentication support.

  ## Tables Created

  ### 1. profiles
  User profile information linked to Supabase auth.users
  - `id` (uuid, primary key) - Links to auth.users
  - `email` (text) - User email
  - `phone` (text) - Phone number
  - `full_name` (text) - Full name
  - `created_at` (timestamptz) - Account creation time
  - `updated_at` (timestamptz) - Last update time

  ### 2. addresses
  Customer shipping addresses
  - `id` (uuid, primary key)
  - `user_id` (uuid, foreign key to profiles)
  - `full_name` (text) - Recipient name
  - `phone` (text) - Contact phone
  - `address_line1` (text) - Street address
  - `address_line2` (text, optional) - Additional address info
  - `city` (text) - City
  - `state` (text) - State
  - `pincode` (text) - Postal code
  - `is_default` (boolean) - Default address flag
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 3. products
  Product catalog
  - `id` (uuid, primary key)
  - `name` (text) - Product name
  - `description` (text) - Product description
  - `category` (text) - Product category
  - `price` (numeric) - Product price
  - `image_url` (text) - Product image
  - `stock_quantity` (integer) - Available stock
  - `is_active` (boolean) - Product visibility
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 4. orders
  Customer orders
  - `id` (uuid, primary key)
  - `user_id` (uuid, foreign key to profiles)
  - `order_number` (text, unique) - Human-readable order number
  - `status` (text) - Order status (pending, processing, shipped, delivered, cancelled)
  - `payment_status` (text) - Payment status (pending, paid, failed)
  - `payment_method` (text) - Payment method used
  - `subtotal` (numeric) - Items subtotal
  - `shipping_cost` (numeric) - Shipping charges
  - `total_amount` (numeric) - Total order amount
  - `customer_name` (text) - Customer name
  - `customer_email` (text) - Customer email
  - `customer_phone` (text) - Customer phone
  - `shipping_address` (jsonb) - Complete shipping address
  - `qr_code_data` (text, optional) - Payment QR code data
  - `transaction_id` (text, optional) - Payment transaction ID
  - `estimated_delivery` (date, optional) - Estimated delivery date
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 5. order_items
  Individual items in orders
  - `id` (uuid, primary key)
  - `order_id` (uuid, foreign key to orders)
  - `product_id` (uuid, foreign key to products)
  - `product_name` (text) - Product name snapshot
  - `product_price` (numeric) - Price at time of order
  - `quantity` (integer) - Quantity ordered
  - `subtotal` (numeric) - Line item subtotal
  - `created_at` (timestamptz)

  ### 6. inquiries
  Customer product inquiries
  - `id` (uuid, primary key)
  - `user_type` (text) - Customer type (individual, business)
  - `product_interest` (text) - Product of interest
  - `full_name` (text) - Contact name
  - `email` (text) - Contact email
  - `phone` (text) - Contact phone
  - `location` (text) - Customer location
  - `message` (text, optional) - Additional message
  - `status` (text) - Inquiry status (new, contacted, closed)
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 7. owner_accounts
  Store owner/admin accounts
  - `id` (uuid, primary key) - Links to auth.users
  - `email` (text) - Admin email
  - `full_name` (text) - Admin name
  - `role` (text) - Admin role
  - `created_at` (timestamptz)

  ## Security (Row Level Security)

  All tables have RLS enabled with policies that:
  - Allow authenticated users to read their own data
  - Allow authenticated users to insert/update their own data
  - Allow anonymous users to read public product data
  - Allow anonymous users to create orders and inquiries
  - Restrict admin operations to owner accounts

  ## Indexes

  Created indexes for:
  - Foreign key relationships
  - Frequently queried fields (email, phone, order_number)
  - Order status and dates
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  phone text,
  full_name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create addresses table
CREATE TABLE IF NOT EXISTS addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  full_name text NOT NULL,
  phone text NOT NULL,
  address_line1 text NOT NULL,
  address_line2 text,
  city text NOT NULL,
  state text NOT NULL,
  pincode text NOT NULL,
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  category text NOT NULL,
  price numeric(10,2) NOT NULL CHECK (price >= 0),
  image_url text NOT NULL,
  stock_quantity integer DEFAULT 0 CHECK (stock_quantity >= 0),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  order_number text UNIQUE NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled')),
  payment_status text DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed')),
  payment_method text NOT NULL,
  subtotal numeric(10,2) NOT NULL CHECK (subtotal >= 0),
  shipping_cost numeric(10,2) DEFAULT 0 CHECK (shipping_cost >= 0),
  total_amount numeric(10,2) NOT NULL CHECK (total_amount >= 0),
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_phone text NOT NULL,
  shipping_address jsonb NOT NULL,
  qr_code_data text,
  transaction_id text,
  estimated_delivery date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create order_items table
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE NOT NULL,
  product_id uuid REFERENCES products(id) ON DELETE SET NULL,
  product_name text NOT NULL,
  product_price numeric(10,2) NOT NULL CHECK (product_price >= 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  subtotal numeric(10,2) NOT NULL CHECK (subtotal >= 0),
  created_at timestamptz DEFAULT now()
);

-- Create inquiries table
CREATE TABLE IF NOT EXISTS inquiries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_type text NOT NULL CHECK (user_type IN ('individual', 'business')),
  product_interest text NOT NULL,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  location text NOT NULL,
  message text,
  status text DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'closed')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create owner_accounts table
CREATE TABLE IF NOT EXISTS owner_accounts (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL,
  role text DEFAULT 'admin',
  created_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_inquiries_status ON inquiries(status);
CREATE INDEX IF NOT EXISTS idx_inquiries_created_at ON inquiries(created_at DESC);

-- Enable Row Level Security on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE owner_accounts ENABLE ROW LEVEL SECURITY;

-- Profiles policies
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

-- Addresses policies
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

-- Products policies (public read, admin write)
CREATE POLICY "Anyone can view active products"
  ON products FOR SELECT
  TO public
  USING (is_active = true);

CREATE POLICY "Authenticated users can view all products"
  ON products FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only owners can manage products"
  ON products FOR ALL
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

-- Orders policies
CREATE POLICY "Users can view own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Anonymous users can create orders"
  ON orders FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Authenticated users can create orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can update own pending orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Owners can view all orders"
  ON orders FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

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

-- Order items policies
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

CREATE POLICY "Anonymous users can create order items"
  ON order_items FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Authenticated users can create order items"
  ON order_items FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Owners can view all order items"
  ON order_items FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

-- Inquiries policies
CREATE POLICY "Anonymous users can create inquiries"
  ON inquiries FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Authenticated users can create inquiries"
  ON inquiries FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Owners can view all inquiries"
  ON inquiries FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM owner_accounts
      WHERE owner_accounts.id = auth.uid()
    )
  );

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

-- Owner accounts policies
CREATE POLICY "Owners can view own account"
  ON owner_accounts FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_addresses_updated_at
  BEFORE UPDATE ON addresses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inquiries_updated_at
  BEFORE UPDATE ON inquiries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
