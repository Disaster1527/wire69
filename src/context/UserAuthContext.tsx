import { ReactNode, createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { toast } from "sonner";
import { supabase, isSupabaseConfigured } from "@/lib/supabase";
import type { User, Session } from "@supabase/supabase-js";

type UserProfile = {
  id: string;
  contact: string;
  lastLoginAt: string;
};

type PendingVerification = {
  contact: string;
  type: 'phone' | 'email';
};

type UserAuthContextValue = {
  user: UserProfile | null;
  isAuthenticated: boolean;
  requestOtp: (contact: string) => Promise<void>;
  verifyOtp: (contact: string, otp: string) => Promise<void>;
  logout: () => void;
  session: Session | null;
};

const UserAuthContext = createContext<UserAuthContextValue | undefined>(undefined);

const isValidEmail = (value: string) => {
  return /^(?:[a-zA-Z0-9_!#$%&'*+/=?`{|}~^.-]+)@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/u.test(value.trim());
};

const isValidPhone = (value: string) => {
  return /^(\+\d{1,3})?\d{10}$/.test(value.replace(/[\s-]/g, ''));
};

const normalizePhone = (phone: string): string => {
  const cleaned = phone.replace(/[\s-]/g, '');
  if (cleaned.startsWith('+')) {
    return cleaned;
  }
  if (cleaned.length === 10) {
    return `+91${cleaned}`;
  }
  return `+${cleaned}`;
};

export const UserAuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [pending, setPending] = useState<PendingVerification | null>(null);

  useEffect(() => {
    if (!isSupabaseConfigured) return;

    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session?.user) {
        const contact = session.user.phone || session.user.email || '';
        setUser({
          id: session.user.id,
          contact,
          lastLoginAt: new Date().toISOString(),
        });
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      (async () => {
        setSession(session);
        if (session?.user) {
          const contact = session.user.phone || session.user.email || '';
          setUser({
            id: session.user.id,
            contact,
            lastLoginAt: new Date().toISOString(),
          });

          await supabase
            .from('profiles')
            .upsert({
              id: session.user.id,
              email: session.user.email || '',
              phone: session.user.phone || '',
              updated_at: new Date().toISOString(),
            }, {
              onConflict: 'id',
            });
        } else {
          setUser(null);
        }
      })();
    });

    return () => subscription.unsubscribe();
  }, []);

  const requestOtp = useCallback(async (contact: string) => {
    const trimmed = contact.trim();

    if (!isSupabaseConfigured) {
      throw new Error("Authentication is not configured. Please check your setup.");
    }

    const isEmail = isValidEmail(trimmed);
    const isPhone = isValidPhone(trimmed);

    if (!isEmail && !isPhone) {
      throw new Error("Enter a valid mobile number (with country code) or email address.");
    }

    try {
      if (isPhone) {
        const phone = normalizePhone(trimmed);
        const { error } = await supabase.auth.signInWithOtp({
          phone,
          options: {
            channel: 'sms',
          },
        });

        if (error) throw error;

        setPending({ contact: phone, type: 'phone' });

        toast.success("OTP sent successfully", {
          description: "Please check your phone for the verification code.",
        });
      } else {
        const { error } = await supabase.auth.signInWithOtp({
          email: trimmed,
          options: {
            shouldCreateUser: true,
          },
        });

        if (error) throw error;

        setPending({ contact: trimmed, type: 'email' });

        toast.success("OTP sent successfully", {
          description: "Please check your email for the verification code.",
        });
      }
    } catch (error: any) {
      console.error('OTP request error:', error);
      throw new Error(error.message || "Failed to send OTP. Please try again.");
    }
  }, []);

  const verifyOtp = useCallback(
    async (contact: string, otp: string) => {
      if (!isSupabaseConfigured) {
        throw new Error("Authentication is not configured. Please check your setup.");
      }

      if (!pending) {
        throw new Error("Please request an OTP first.");
      }

      if (!/^[0-9]{6}$/.test(otp.trim())) {
        throw new Error("Enter the 6-digit OTP sent to you.");
      }

      try {
        if (pending.type === 'phone') {
          const phone = normalizePhone(contact);
          const { data, error } = await supabase.auth.verifyOtp({
            phone,
            token: otp.trim(),
            type: 'sms',
          });

          if (error) throw error;

          if (data.user) {
            await supabase
              .from('profiles')
              .upsert({
                id: data.user.id,
                phone: data.user.phone || '',
                email: data.user.email || '',
                updated_at: new Date().toISOString(),
              }, {
                onConflict: 'id',
              });
          }
        } else {
          const { data, error } = await supabase.auth.verifyOtp({
            email: contact.trim(),
            token: otp.trim(),
            type: 'email',
          });

          if (error) throw error;

          if (data.user) {
            await supabase
              .from('profiles')
              .upsert({
                id: data.user.id,
                email: data.user.email || '',
                phone: data.user.phone || '',
                updated_at: new Date().toISOString(),
              }, {
                onConflict: 'id',
              });
          }
        }

        setPending(null);

        toast.success("Login successful", {
          description: "You are now securely logged in.",
        });
      } catch (error: any) {
        console.error('OTP verification error:', error);
        throw new Error(error.message || "Invalid OTP. Please try again.");
      }
    },
    [pending],
  );

  const logout = useCallback(async () => {
    if (isSupabaseConfigured) {
      await supabase.auth.signOut();
    }
    setUser(null);
    setSession(null);
    toast.info("You have been logged out.");
  }, []);

  const value = useMemo<UserAuthContextValue>(
    () => ({
      user,
      isAuthenticated: Boolean(user),
      requestOtp,
      verifyOtp,
      logout,
      session,
    }),
    [logout, requestOtp, user, verifyOtp, session],
  );

  return <UserAuthContext.Provider value={value}>{children}</UserAuthContext.Provider>;
};

export const useUserAuth = () => {
  const context = useContext(UserAuthContext);
  if (!context) {
    throw new Error("useUserAuth must be used within a UserAuthProvider");
  }
  return context;
};
