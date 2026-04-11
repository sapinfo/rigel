import type { SupabaseClient, Session, User } from '@supabase/supabase-js';
import type { CurrentTenant } from '$lib/types/approval';

declare global {
  namespace App {
    // interface Error {}
    interface Locals {
      // Supabase server client injected by hooks.server.ts
      // Database generic will be added in M5 after `npm run gen:types`
      supabase: SupabaseClient;
      safeGetSession: () => Promise<{ session: Session | null; user: User | null }>;
      session: Session | null;
      user: User | null;
      currentTenant: CurrentTenant | null;
    }
    interface PageData {
      session: Session | null;
      user: User | null;
      currentTenant: CurrentTenant | null;
    }
    // interface PageState {}
    // interface Platform {}
  }
}

export {};
