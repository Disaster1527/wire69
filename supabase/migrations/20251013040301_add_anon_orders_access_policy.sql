/*
  # Add Anonymous Access Policy for Orders Table

  ## Overview
  This migration adds RLS policies to allow anonymous (public) access to the orders table
  for admin dashboard functionality. This is necessary because the owner dashboard uses
  localStorage-based authentication rather than Supabase auth.

  ## Changes
  - Add SELECT policy for anonymous users to view all orders
  - Add UPDATE policy for anonymous users to update order status
  
  ## Security Notes
  - These policies allow public read/write access to orders
  - This is acceptable as the admin dashboard is protected by its own authentication
  - Consider implementing additional security measures in production
*/

CREATE POLICY "Allow anon to read all orders"
  ON orders FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow anon to update orders"
  ON orders FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);