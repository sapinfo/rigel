import type { SupabaseClient } from '@supabase/supabase-js';

const BUCKET = 'approval-attachments';
const TTL_SECONDS = 300;

/**
 * Create a signed download URL. The `download` option sets
 * Content-Disposition so the browser uses the original filename
 * (even though the storage path is upload_uuid.ext).
 */
export async function createDownloadUrl(
  supabase: SupabaseClient,
  storagePath: string,
  originalFileName: string
): Promise<string | null> {
  const { data, error } = await supabase.storage
    .from(BUCKET)
    .createSignedUrl(storagePath, TTL_SECONDS, {
      download: originalFileName
    });
  if (error || !data) return null;
  return data.signedUrl;
}

/**
 * Parallel signing for a list of attachments.
 * Returns a map keyed by storage_path.
 */
export async function createDownloadUrls(
  supabase: SupabaseClient,
  attachments: Array<{ storage_path: string; file_name: string }>
): Promise<Record<string, string>> {
  if (attachments.length === 0) return {};
  const entries = await Promise.all(
    attachments.map(async (a) => {
      const url = await createDownloadUrl(supabase, a.storage_path, a.file_name);
      return [a.storage_path, url ?? ''] as const;
    })
  );
  return Object.fromEntries(entries);
}
