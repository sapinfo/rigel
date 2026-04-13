<script lang="ts">
  import { page } from '$app/state';

  type Props = { slug: string };
  let { slug }: Props = $props();

  const links = [
    ['members', '멤버'],
    ['org', '조직 관리'],
    ['forms', '양식'],
    ['approval-rules', '결재선 규칙'],
    ['approval-templates', '결재선 템플릿'],
    ['delegations', '전결 규칙'],
    ['absences', '부재 관리'],
    ['audit', '감사 로그']
  ];
</script>

<nav class="flex gap-1 overflow-x-auto border-b mb-4">
  {#each links as [path, label] (path)}
    <a href="/t/{slug}/admin/{path}"
       class="shrink-0 px-3 py-2 text-sm"
       class:border-b-2={page.url.pathname.includes(`/admin/${path}`)}
       class:border-blue-600={page.url.pathname.includes(`/admin/${path}`)}
       class:text-blue-600={page.url.pathname.includes(`/admin/${path}`)}
       class:text-gray-500={!page.url.pathname.includes(`/admin/${path}`)}>
      {label}
    </a>
  {/each}
</nav>
