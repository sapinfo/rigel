import { browser } from '$app/environment';
import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

/**
 * Client-side attachment upload.
 * Storage path: {tenant_id}/{YYYY-MM}/{upload_uuid}.{ext}
 * Original filename is stored in approval_attachments.file_name only.
 */

function extractExt(fileName: string): string {
  const match = /\.([a-zA-Z0-9]{1,10})$/.exec(fileName);
  return match ? match[1].toLowerCase() : 'bin';
}

function currentMonthKST(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit'
  }).format(new Date());
}

export type UploadedAttachment = {
  id: string;
  fileName: string;
  size: number;
  mime: string;
};

// v1.2 M16b: 클라이언트 SHA-256 계산 (crypto.subtle.digest).
// 업로드와 병렬로 수행하면 총 시간 줄어들지만, Storage 업로드 실패 시 해시 불필요하므로 순차.
async function computeFileSha256(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  const arr = new Uint8Array(digest);
  let out = '';
  for (const b of arr) {
    out += b.toString(16).padStart(2, '0');
  }
  return out;
}

export async function uploadAttachment(
  tenantId: string,
  file: File
): Promise<UploadedAttachment> {
  if (!browser) throw new Error('Client only');

  const supabase = createBrowserClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY
  );

  const uploadUuid = crypto.randomUUID();
  const ext = extractExt(file.name);
  const month = currentMonthKST();
  const storagePath = `${tenantId}/${month}/${uploadUuid}.${ext}`;

  // v1.2: 업로드 전 sha256 계산 (업로드 실패 시 DB insert 없음 → 낭비 없음)
  const sha256 = await computeFileSha256(file);

  const { error: upErr } = await supabase.storage
    .from('approval-attachments')
    .upload(storagePath, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type || 'application/octet-stream'
    });
  if (upErr) throw upErr;

  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) {
    await supabase.storage.from('approval-attachments').remove([storagePath]);
    throw new Error('Not authenticated');
  }

  const { data: row, error: insErr } = await supabase
    .from('approval_attachments')
    .insert({
      tenant_id: tenantId,
      storage_path: storagePath,
      file_name: file.name,
      mime: file.type || 'application/octet-stream',
      size: file.size,
      sha256,
      uploaded_by: user.id,
      document_id: null
    })
    .select('id')
    .single();

  if (insErr || !row) {
    await supabase.storage.from('approval-attachments').remove([storagePath]);
    throw insErr ?? new Error('Attachment insert failed');
  }

  return {
    id: row.id as string,
    fileName: file.name,
    size: file.size,
    mime: file.type || 'application/octet-stream'
  };
}
