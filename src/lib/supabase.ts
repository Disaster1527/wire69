import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl as string, supabaseAnonKey as string)
  : ({} as any);

export type Database = {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          contact: string;
          last_login_at: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          contact: string;
          last_login_at?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          contact?: string;
          last_login_at?: string;
          created_at?: string;
        };
      };
      orders: {
        Row: {
          id: string;
          user_id: string;
          order_number: string;
          customer_name: string;
          customer_email: string;
          customer_phone: string;
          customer_address: string;
          customer_pincode: string;
          items: any;
          subtotal: number;
          shipping_cost: number;
          total_amount: number;
          status: string;
          payment_status: string;
          payment_method: string;
          qr_code_data: string | null;
          transaction_id: string | null;
          estimated_delivery: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          order_number: string;
          customer_name: string;
          customer_email: string;
          customer_phone: string;
          customer_address: string;
          customer_pincode: string;
          items: any;
          subtotal: number;
          shipping_cost: number;
          total_amount: number;
          status?: string;
          payment_status?: string;
          payment_method?: string;
          qr_code_data?: string | null;
          transaction_id?: string | null;
          estimated_delivery?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          order_number?: string;
          customer_name?: string;
          customer_email?: string;
          customer_phone?: string;
          customer_address?: string;
          customer_pincode?: string;
          items?: any;
          subtotal?: number;
          shipping_cost?: number;
          total_amount?: number;
          status?: string;
          payment_status?: string;
          payment_method?: string;
          qr_code_data?: string | null;
          transaction_id?: string | null;
          estimated_delivery?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
    };
  };
};
