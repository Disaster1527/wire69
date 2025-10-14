import type { InquiryData } from "@/pages/Inquiry";

export interface StoredInquiry extends InquiryData {
  id: string;
  createdAt: string;
}

export const INQUIRY_STORAGE_KEY = "owner-dashboard-inquiries";

type ParsedValue = unknown;

const isStoredInquiryArray = (value: ParsedValue): value is StoredInquiry[] => {
  if (!Array.isArray(value)) {
    return false;
  }

  return value.every((item) =>
    item &&
    typeof item === "object" &&
    "id" in item &&
    "createdAt" in item &&
    "userType" in item &&
    "phone" in item &&
    "email" in item &&
    "address" in item &&
    "pincode" in item &&
    "brand" in item &&
    "color" in item &&
    "quantity" in item &&
    "unit" in item,
  );
};

const readStorage = (): StoredInquiry[] => {
  if (typeof window === "undefined") {
    return [];
  }

  try {
    const raw = window.localStorage.getItem(INQUIRY_STORAGE_KEY);

    if (!raw) {
      return [];
    }

    const parsed = JSON.parse(raw) as ParsedValue;

    if (!isStoredInquiryArray(parsed)) {
      return [];
    }

    return parsed;
  } catch (error) {
    console.error("Failed to read inquiries from storage", error);
    return [];
  }
};

const writeStorage = (value: StoredInquiry[]) => {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.localStorage.setItem(INQUIRY_STORAGE_KEY, JSON.stringify(value));
  } catch (error) {
    console.error("Failed to write inquiries to storage", error);
  }
};

export const getStoredInquiries = (): StoredInquiry[] => readStorage();

export const addInquiryToStorage = (data: InquiryData): StoredInquiry => {
  const newInquiry: StoredInquiry = {
    ...data,
    id: typeof crypto !== "undefined" && "randomUUID" in crypto ? crypto.randomUUID() : `${Date.now()}`,
    createdAt: new Date().toISOString(),
  };

  const inquiries = [...readStorage(), newInquiry];
  writeStorage(inquiries);
  return newInquiry;
};

export const clearStoredInquiries = () => {
  writeStorage([]);
};

export const removeInquiryFromStorage = (id: string) => {
  const next = readStorage().filter((inquiry) => inquiry.id !== id);
  writeStorage(next);
};
