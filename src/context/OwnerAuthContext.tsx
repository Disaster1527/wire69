import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { supabase, isSupabaseConfigured } from "@/lib/supabase";
import type { Session } from "@supabase/supabase-js";
import { toast } from "sonner";

interface OwnerAuthContextValue {
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
  session: Session | null;
}

const OwnerAuthContext = createContext<OwnerAuthContextValue | undefined>(undefined);

export const OwnerAuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [session, setSession] = useState<Session | null>(null);

  useEffect(() => {
    if (!isSupabaseConfigured) return;

    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      if (session?.user) {
        supabase
          .from('owner_accounts')
          .select('id')
          .eq('id', session.user.id)
          .maybeSingle()
          .then(({ data }) => {
            setIsAuthenticated(!!data);
          });
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      (async () => {
        setSession(session);
        if (session?.user) {
          const { data } = await supabase
            .from('owner_accounts')
            .select('id')
            .eq('id', session.user.id)
            .maybeSingle();

          setIsAuthenticated(!!data);
        } else {
          setIsAuthenticated(false);
        }
      })();
    });

    return () => subscription.unsubscribe();
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    if (!isSupabaseConfigured) {
      toast.error("Authentication is not configured");
      return false;
    }

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password: password.trim(),
      });

      if (error) throw error;

      if (data.user) {
        const { data: ownerData } = await supabase
          .from('owner_accounts')
          .select('id')
          .eq('id', data.user.id)
          .maybeSingle();

        if (!ownerData) {
          await supabase.auth.signOut();
          toast.error("Access denied. Owner account required.");
          return false;
        }

        setIsAuthenticated(true);
        toast.success("Welcome back!");
        return true;
      }

      return false;
    } catch (error: any) {
      console.error('Login error:', error);
      toast.error(error.message || "Invalid credentials");
      return false;
    }
  }, []);

  const logout = useCallback(async () => {
    if (isSupabaseConfigured) {
      await supabase.auth.signOut();
    }
    setIsAuthenticated(false);
    setSession(null);
    toast.info("Logged out successfully");
  }, []);

  const value = useMemo(
    () => ({
      isAuthenticated,
      login,
      logout,
      session,
    }),
    [isAuthenticated, login, logout, session],
  );

  return <OwnerAuthContext.Provider value={value}>{children}</OwnerAuthContext.Provider>;
};

export const useOwnerAuth = () => {
  const context = useContext(OwnerAuthContext);

  if (!context) {
    throw new Error("useOwnerAuth must be used within an OwnerAuthProvider");
  }

  return context;
};
