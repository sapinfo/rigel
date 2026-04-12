<script lang="ts">
  let { data } = $props();

  const hour = new Date().getHours();
  const greeting = hour < 12 ? '좋은 아침입니다' : hour < 18 ? '안녕하세요' : '수고하셨습니다';

  const slug = data.currentTenant.slug;

  const cards = [
    { key: 'pending', label: '미결', count: data.counts.pending, href: `/t/${slug}/approval/inbox?tab=pending`, color: 'text-red-600' },
    { key: 'inProgress', label: '상신진행', count: data.counts.inProgress, href: `/t/${slug}/approval/inbox?tab=in_progress`, color: 'text-blue-600' },
    { key: 'completed', label: '완료', count: data.counts.completed, href: `/t/${slug}/approval/inbox?tab=completed`, color: 'text-green-600' },
    { key: 'rejected', label: '반려', count: data.counts.rejected, href: `/t/${slug}/approval/inbox?tab=rejected`, color: 'text-red-500' },
    { key: 'drafts', label: '임시저장', count: data.counts.drafts, href: `/t/${slug}/approval/inbox?tab=drafts`, color: 'text-gray-600' },
    { key: 'urgent', label: '긴급 미결', count: data.urgentCount, href: `/t/${slug}/approval/inbox?tab=pending`, color: 'text-red-700' }
  ];
</script>

<div class="space-y-6">
  <!-- 인사말 -->
  <div>
    <h1 class="text-xl font-bold">{greeting}, {data.userName}님</h1>
    <p class="text-sm text-gray-500">{data.currentTenant.name}</p>
  </div>

  <!-- 6카드 -->
  <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
    {#each cards as card (card.key)}
      <a href={card.href} class="rounded-lg border bg-white p-4 transition hover:shadow">
        <p class="text-2xl font-bold {card.color}">{card.count}</p>
        <p class="text-xs text-gray-500">{card.label}</p>
      </a>
    {/each}
  </div>

  <!-- 즐겨찾기 -->
  {#if data.favorites.length > 0}
    <section class="rounded-lg border bg-white p-4">
      <h2 class="mb-2 text-sm font-semibold">즐겨찾기 결재선</h2>
      {#each data.favorites as fav (fav.id)}
        <div class="flex items-center justify-between border-b py-1.5 last:border-b-0">
          <span class="text-sm">{fav.name}</span>
        </div>
      {/each}
    </section>
  {/if}

  <!-- 최근 기안문서 -->
  {#if data.recentDocuments.length > 0}
    <section class="rounded-lg border bg-white p-4">
      <div class="mb-2 flex items-center justify-between">
        <h2 class="text-sm font-semibold">최근 기안 문서</h2>
        <a href="/t/{slug}/approval/inbox?tab=in_progress" class="text-xs text-blue-600 hover:underline">전체보기</a>
      </div>
      <ul class="divide-y">
        {#each data.recentDocuments as doc (doc.id)}
          <li>
            <a href="/t/{slug}/approval/documents/{doc.id}" class="flex items-center gap-3 py-2 text-sm hover:bg-gray-50">
              <span class="w-28 shrink-0 font-mono text-xs text-gray-400">{doc.docNumber}</span>
              {#if doc.urgency === '긴급'}
                <span class="rounded bg-red-100 px-1 py-0.5 text-[10px] text-red-700">긴급</span>
              {/if}
              <span class="flex-1 truncate">{doc.formName}</span>
              <span class="w-14 shrink-0 rounded px-1.5 py-0.5 text-center text-xs"
                class:bg-yellow-100={doc.status === 'draft'}
                class:bg-blue-100={doc.status === 'in_progress'}
                class:bg-green-100={doc.status === 'completed'}
                class:bg-red-100={doc.status === 'rejected'}>
                {doc.status === 'draft' ? '임시' : doc.status === 'in_progress' ? '진행' : doc.status === 'completed' ? '완료' : doc.status === 'rejected' ? '반려' : doc.status}
              </span>
            </a>
          </li>
        {/each}
      </ul>
    </section>
  {/if}

  <!-- 부재 현황 -->
  {#if data.absentMembers.length > 0}
    <section class="rounded-lg border bg-white p-4">
      <h2 class="mb-2 text-sm font-semibold">부재 현황</h2>
      {#each data.absentMembers as m, i (i)}
        <p class="text-sm text-gray-600">{m.name} → 대결: {m.proxyName}</p>
      {/each}
    </section>
  {/if}

  <!-- 빠른 기안 -->
  {#if data.forms.length > 0}
    <section class="rounded-lg border bg-white p-4">
      <h2 class="mb-2 text-sm font-semibold">새 기안</h2>
      <div class="flex flex-wrap gap-2">
        {#each data.forms as f (f.code)}
          <a href="/t/{slug}/approval/drafts/new/{f.code}" class="rounded border px-3 py-1.5 text-sm hover:bg-gray-50">
            {f.name}
          </a>
        {/each}
      </div>
    </section>
  {/if}
</div>
