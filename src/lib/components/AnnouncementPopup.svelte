<script lang="ts">
  import { createBrowserClient } from '@supabase/ssr';
  import { env } from '$env/dynamic/public';

  interface PopupAnnouncement {
    id: string;
    title: string;
    content: Record<string, unknown>;
    publishedAt: string;
  }

  interface Props {
    announcements: PopupAnnouncement[];
    tenantId: string;
  }

  let { announcements, tenantId }: Props = $props();

  let currentIndex = $state(0);
  let dismissed = $state(false);

  const current = $derived(announcements[currentIndex]);
  const total = $derived(announcements.length);
  const hasMore = $derived(currentIndex < total - 1);

  async function markRead(id: string) {
    const supabase = createBrowserClient(env.PUBLIC_SUPABASE_URL!, env.PUBLIC_SUPABASE_ANON_KEY!);
    await supabase.from('announcement_reads').insert({
      announcement_id: id,
      user_id: (await supabase.auth.getUser()).data.user?.id,
      tenant_id: tenantId
    });
  }

  async function handleConfirm() {
    await markRead(current.id);
    if (hasMore) {
      currentIndex++;
    } else {
      dismissed = true;
    }
  }

  function handleDismissAll() {
    // Mark all as read without waiting
    announcements.forEach((a) => markRead(a.id));
    dismissed = true;
  }

  function renderText(content: Record<string, unknown>): string {
    // Simple Tiptap JSON → text extraction
    if (content?.type === 'doc' && Array.isArray(content.content)) {
      return (content.content as Array<Record<string, unknown>>)
        .map((node) => {
          if (Array.isArray(node.content)) {
            return (node.content as Array<Record<string, unknown>>)
              .map((c) => (c.text as string) ?? '')
              .join('');
          }
          return '';
        })
        .join('\n');
    }
    return JSON.stringify(content);
  }
</script>

{#if !dismissed && total > 0 && current}
  <!-- Overlay -->
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
    <div class="w-full max-w-lg rounded-lg bg-white shadow-xl mx-4">
      <!-- Header -->
      <div class="flex items-center justify-between border-b px-5 py-3">
        <div class="flex items-center gap-2">
          <span class="rounded bg-red-100 px-2 py-0.5 text-xs font-medium text-red-700">필독</span>
          <span class="text-xs text-gray-400">{currentIndex + 1} / {total}</span>
        </div>
        <button type="button" class="text-xs text-gray-400 hover:text-gray-600" onclick={handleDismissAll}>
          모두 닫기
        </button>
      </div>

      <!-- Body -->
      <div class="px-5 py-4">
        <h2 class="text-lg font-bold mb-2">{current.title}</h2>
        <div class="text-sm text-gray-700 whitespace-pre-wrap max-h-60 overflow-y-auto">
          {renderText(current.content)}
        </div>
        <p class="mt-3 text-xs text-gray-400">
          {new Date(current.publishedAt).toLocaleDateString('ko-KR')}
        </p>
      </div>

      <!-- Footer -->
      <div class="flex justify-end gap-2 border-t px-5 py-3">
        <button
          type="button"
          class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700"
          onclick={handleConfirm}
        >
          {hasMore ? '확인 (다음)' : '확인'}
        </button>
      </div>
    </div>
  </div>
{/if}
