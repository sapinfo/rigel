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
    { key: 'urgent', label: '긴급', count: data.urgentCount, href: `/t/${slug}/approval/inbox?tab=pending`, color: 'text-red-700' }
  ];
</script>

<div class="space-y-5">
  <!-- 인사말 -->
  <div>
    <h1 class="text-xl font-bold">{greeting}, {data.userName}님</h1>
    <p class="text-sm text-gray-500">{data.currentTenant.name}</p>
  </div>

  <!-- 6카드 -->
  <div class="grid grid-cols-3 gap-3 lg:grid-cols-6">
    {#each cards as card (card.key)}
      <a href={card.href} class="rounded-lg border bg-white p-3 transition hover:shadow">
        <p class="text-2xl font-bold {card.color}">{card.count}</p>
        <p class="text-xs text-gray-500">{card.label}</p>
      </a>
    {/each}
  </div>

  <!-- 빠른 기안 (카드 바로 아래) -->
  {#if data.forms.length > 0}
    <div class="flex flex-wrap gap-2">
      {#each data.forms as f (f.code)}
        <a href="/t/{slug}/approval/drafts/new/{f.code}" class="rounded-lg border bg-white px-4 py-2 text-sm font-medium hover:shadow">
          + {f.name}
        </a>
      {/each}
    </div>
  {/if}

  <!-- 최근 기안문서 -->
  {#if data.recentDocuments.length > 0}
    <section class="rounded-lg border bg-white p-4">
      <div class="mb-2 flex items-center justify-between">
        <h2 class="text-sm font-semibold">최근 기안 문서</h2>
        <a href="/t/{slug}/approval/inbox" class="text-xs text-blue-600 hover:underline">전체보기</a>
      </div>
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b text-left text-xs text-gray-400">
            <th class="py-1.5 font-normal">문서번호</th>
            <th class="py-1.5 font-normal">양식</th>
            <th class="py-1.5 font-normal">제목</th>
            <th class="py-1.5 font-normal text-center">상태</th>
          </tr>
        </thead>
        <tbody>
          {#each data.recentDocuments as doc (doc.id)}
            <tr class="border-b last:border-b-0 hover:bg-gray-50">
              <td class="py-1.5 pr-2">
                <a href="/t/{slug}/approval/documents/{doc.id}" class="font-mono text-xs text-gray-500 hover:text-blue-600">{doc.docNumber}</a>
              </td>
              <td class="py-1.5 pr-2 text-xs text-gray-500">
                {doc.formName}
                {#if doc.urgency === '긴급'}
                  <span class="ml-1 rounded bg-red-100 px-1 py-0.5 text-[10px] text-red-700">긴급</span>
                {/if}
              </td>
              <td class="py-1.5 pr-2">
                <a href="/t/{slug}/approval/documents/{doc.id}" class="truncate hover:text-blue-600">{doc.title || '(제목 없음)'}</a>
              </td>
              <td class="w-14 py-1.5 text-center">
                <span class="rounded px-1.5 py-0.5 text-xs"
                  class:bg-yellow-100={doc.status === 'draft'}
                  class:bg-blue-100={doc.status === 'in_progress'}
                  class:bg-green-100={doc.status === 'completed'}
                  class:bg-red-100={doc.status === 'rejected'}>
                  {doc.status === 'draft' ? '임시' : doc.status === 'in_progress' ? '진행' : doc.status === 'completed' ? '완료' : doc.status === 'rejected' ? '반려' : doc.status}
                </span>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
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
</div>
