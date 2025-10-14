import { CartItem } from './cart-storage';
import { supabase, isSupabaseConfigured } from './supabase';

export interface Order {
  id: string;
  orderNumber: string;
  userId?: string;
  customerInfo: {
    name: string;
    email: string;
    phone: string;
    address: string;
    pincode: string;
  };
  items: CartItem[];
  subtotal: number;
  shippingCost: number;
  totalAmount: number;
  status: 'pending' | 'confirmed' | 'processing' | 'shipped' | 'delivered' | 'cancelled';
  paymentStatus: 'pending' | 'completed' | 'failed';
  paymentMethod: 'qr_code';
  qrCodeData?: string;
  transactionId?: string;
  createdAt: string;
  estimatedDelivery?: string;
}

const ORDER_STORAGE_KEY = 'wire_cable_orders';

export const getOrders = async (userId?: string): Promise<Order[]> => {
  if (typeof window === 'undefined') return [];
  const stored = localStorage.getItem(ORDER_STORAGE_KEY);
  const all: Order[] = stored ? JSON.parse(stored) : [];

  if (!userId) {
    return all;
  }

  if (!isSupabaseConfigured) {
    return all.filter((o) => o.userId === userId);
  }

  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching orders:', error);
    return [];
  }

  return (data || []).map(order => ({
    id: order.id,
    orderNumber: order.order_number,
    userId: order.user_id,
    customerInfo: {
      name: order.customer_name,
      email: order.customer_email,
      phone: order.customer_phone,
      address: order.customer_address,
      pincode: order.customer_pincode,
    },
    items: order.items,
    subtotal: Number(order.subtotal),
    shippingCost: Number(order.shipping_cost),
    totalAmount: Number(order.total_amount),
    status: order.status as Order['status'],
    paymentStatus: order.payment_status as Order['paymentStatus'],
    paymentMethod: order.payment_method as Order['paymentMethod'],
    qrCodeData: order.qr_code_data || undefined,
    transactionId: order.transaction_id || undefined,
    createdAt: order.created_at,
    estimatedDelivery: order.estimated_delivery || undefined,
  }));
};

export const saveOrder = async (order: Order): Promise<void> => {
  if (!isSupabaseConfigured || !order.userId) {
    if (typeof window === 'undefined') return;
    const orders = await getOrders();
    orders.unshift(order);
    localStorage.setItem(ORDER_STORAGE_KEY, JSON.stringify(orders));
    return;
  }

  const { error } = await supabase
    .from('orders')
    .insert({
      id: order.id,
      user_id: order.userId,
      order_number: order.orderNumber,
      customer_name: order.customerInfo.name,
      customer_email: order.customerInfo.email,
      customer_phone: order.customerInfo.phone,
      customer_address: order.customerInfo.address,
      customer_pincode: order.customerInfo.pincode,
      items: order.items,
      subtotal: order.subtotal,
      shipping_cost: order.shippingCost,
      total_amount: order.totalAmount,
      status: order.status,
      payment_status: order.paymentStatus,
      payment_method: order.paymentMethod,
      qr_code_data: order.qrCodeData,
      transaction_id: order.transactionId,
      estimated_delivery: order.estimatedDelivery,
    });

  if (error) {
    console.error('Error saving order:', error);
    throw new Error('Failed to save order');
  }
};

export const updateOrderStatus = async (orderId: string, status: Order['status'], paymentStatus?: Order['paymentStatus'], userId?: string): Promise<void> => {
  if (!userId || !isSupabaseConfigured) {
    const orders = await getOrders();
    const index = orders.findIndex(o => o.id === orderId);

    if (index >= 0) {
      orders[index].status = status;
      if (paymentStatus) {
        orders[index].paymentStatus = paymentStatus;
      }
      localStorage.setItem(ORDER_STORAGE_KEY, JSON.stringify(orders));
    }
    return;
  }

  const updateData: any = { status, updated_at: new Date().toISOString() };
  if (paymentStatus) {
    updateData.payment_status = paymentStatus;
  }

  const { error } = await supabase
    .from('orders')
    .update(updateData)
    .eq('id', orderId)
    .eq('user_id', userId);

  if (error) {
    console.error('Error updating order status:', error);
    throw new Error('Failed to update order status');
  }
};

export const getOrderById = async (orderId: string, userId?: string): Promise<Order | undefined> => {
  if (!userId || !isSupabaseConfigured) {
    const orders = await getOrders();
    return orders.find(o => o.id === orderId);
  }

  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .eq('id', orderId)
    .eq('user_id', userId)
    .maybeSingle();

  if (error || !data) {
    console.error('Error fetching order:', error);
    return undefined;
  }

  return {
    id: data.id,
    orderNumber: data.order_number,
    userId: data.user_id,
    customerInfo: {
      name: data.customer_name,
      email: data.customer_email,
      phone: data.customer_phone,
      address: data.customer_address,
      pincode: data.customer_pincode,
    },
    items: data.items,
    subtotal: Number(data.subtotal),
    shippingCost: Number(data.shipping_cost),
    totalAmount: Number(data.total_amount),
    status: data.status as Order['status'],
    paymentStatus: data.payment_status as Order['paymentStatus'],
    paymentMethod: data.payment_method as Order['paymentMethod'],
    qrCodeData: data.qr_code_data || undefined,
    transactionId: data.transaction_id || undefined,
    createdAt: data.created_at,
    estimatedDelivery: data.estimated_delivery || undefined,
  };
};

export const generateOrderNumber = (): string => {
  const prefix = 'WB';
  const timestamp = Date.now().toString().slice(-8);
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  return `${prefix}${timestamp}${random}`;
};

export const calculateEstimatedDelivery = (pincode: string): string => {
  const days = pincode.startsWith('4') ? 3 : 5;
  const deliveryDate = new Date();
  deliveryDate.setDate(deliveryDate.getDate() + days);
  return deliveryDate.toISOString();
};

export const calculateShippingCost = (pincode: string, subtotal: number): number => {
  if (subtotal >= 5000) return 0;
  const baseRate = pincode.startsWith('4') ? 50 : 100;
  return baseRate;
};

export const getAllOrdersForAdmin = async (): Promise<Order[]> => {
  if (!isSupabaseConfigured) {
    const stored = localStorage.getItem(ORDER_STORAGE_KEY);
    return stored ? JSON.parse(stored) : [];
  }

  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching all orders:', error);
    const stored = localStorage.getItem(ORDER_STORAGE_KEY);
    return stored ? JSON.parse(stored) : [];
  }

  return (data || []).map(order => ({
    id: order.id,
    orderNumber: order.order_number,
    userId: order.user_id,
    customerInfo: {
      name: order.customer_name,
      email: order.customer_email,
      phone: order.customer_phone,
      address: order.customer_address,
      pincode: order.customer_pincode,
    },
    items: order.items,
    subtotal: Number(order.subtotal),
    shippingCost: Number(order.shipping_cost),
    totalAmount: Number(order.total_amount),
    status: order.status as Order['status'],
    paymentStatus: order.payment_status as Order['paymentStatus'],
    paymentMethod: order.payment_method as Order['paymentMethod'],
    qrCodeData: order.qr_code_data || undefined,
    transactionId: order.transaction_id || undefined,
    createdAt: order.created_at,
    estimatedDelivery: order.estimated_delivery || undefined,
  }));
};
