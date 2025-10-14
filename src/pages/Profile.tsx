import { useMemo } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useUserAuth } from "@/context/UserAuthContext";

const formatContact = (contact: string) => {
  if (/^\S+@\S+\.\S+$/.test(contact)) {
    return contact.toLowerCase();
  }
  const digits = contact.replace(/\D/g, "");
  if (digits.length >= 10) {
    const lastFour = digits.slice(-4);
    return `•••• •••• ${lastFour}`;
  }
  return contact;
};

const Profile = () => {
  const { user, logout } = useUserAuth();

  const formattedContact = useMemo(() => {
    if (!user) return "";
    return formatContact(user.contact);
  }, [user]);

  if (!user) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-accent/10 to-background">
        <div className="container mx-auto px-4 py-24 max-w-xl text-center space-y-6">
          <h1 className="text-3xl font-bold">No active session</h1>
          <p className="text-muted-foreground">
            Please log in or sign up from the header to access your personalized dashboard.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-accent/10 to-background py-16">
      <div className="container mx-auto px-4 max-w-2xl">
        <Card className="border-border/60 shadow-lg">
          <CardHeader>
            <CardTitle className="text-3xl">My Profile</CardTitle>
            <CardDescription>Manage your secure, OTP-based account.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div>
              <h2 className="text-sm font-medium text-muted-foreground">Verified Contact</h2>
              <p className="mt-2 text-lg font-semibold">{formattedContact}</p>
            </div>
            <div>
              <h2 className="text-sm font-medium text-muted-foreground">Last Login</h2>
              <p className="mt-2 text-lg font-semibold">
                {new Date(user.lastLoginAt).toLocaleString()}
              </p>
            </div>
            <Button variant="outline" onClick={logout} className="w-full">
              Logout
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
};

export default Profile;
