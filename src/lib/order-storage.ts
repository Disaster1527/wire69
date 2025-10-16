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
    .select(`
      *,
      order_items (
        id,
        product_id,
        product_name,
        product_price,
        quantity,
        subtotal
      )
    `)
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
      address: order.shipping_address?.address || '',
      pincode: order.shipping_address?.pincode || '',
    },
    items: (order.order_items || []).map((item: any) => ({
      id: item.product_id,
      productName: item.product_name,
      unitPrice: Number(item.product_price),
      quantity: item.quantity,
      brand: '',
      color: '',
      imageUrl: '',
    })),
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

  const { data: insertedOrder, error: orderError } = await supabase
    .from('orders')
    .insert({
      user_id: order.userId,
      order_number: order.orderNumber,
      customer_name: order.customerInfo.name,
      customer_email: order.customerInfo.email,
      customer_phone: order.customerInfo.phone,
      shipping_address: {
        address: order.customerInfo.address,
        pincode: order.customerInfo.pincode,
        name: order.customerInfo.name,
        phone: order.customerInfo.phone,
      },
      subtotal: order.subtotal,
      shipping_cost: order.shippingCost,
      total_amount: order.totalAmount,
      status: order.status,
      payment_status: order.paymentStatus,
      payment_method: order.paymentMethod,
      qr_code_data: order.qrCodeData,
      transaction_id: order.transactionId,
      estimated_delivery: order.estimatedDelivery,
    })
    .select()
    .single();

  if (orderError) {
    console.error('Error saving order:', orderError);
    throw new Error('Failed to save order');
  }

  const orderItems = order.items.map(item => ({
    order_id: insertedOrder.id,
    product_id: item.id,
    product_name: item.productName,
    product_price: item.unitPrice,
    quantity: item.quantity,
    subtotal: item.unitPrice * item.quantity,
  }));

  const { error: itemsError } = await supabase
    .from('order_items')
    .insert(orderItems);

  if (itemsError) {
    console.error('Error saving order items:', itemsError);
    throw new Error('Failed to save order items');
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
    .select(`
      *,
      order_items (
        id,
        product_id,
        product_name,
        product_price,
        quantity,
        subtotal
      )
    `)
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
      address: data.shipping_address?.address || '',
      pincode: data.shipping_address?.pincode || '',
    },
    items: (data.order_items || []).map((item: any) => ({
      id: item.product_id,
      productName: item.product_name,
      unitPrice: Number(item.product_price),
      quantity: item.quantity,
      brand: '',
      color: '',
      imageUrl: '',
    })),
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
    .select(`
      *,
      order_items (
        id,
        product_id,
        product_name,
        product_price,
        quantity,
        subtotal
      )
    `)
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
      address: order.shipping_address?.address || '',
      pincode: order.shipping_address?.pincode || '',
    },
    items: (order.order_items || []).map((item: any) => ({
      id: item.product_id,
      productName: item.product_name,
      unitPrice: Number(item.product_price),
      quantity: item.quantity,
      brand: '',
      color: '',
      imageUrl: '',
    })),
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
