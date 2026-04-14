<script lang="ts">
  /**
   * ProfileCard — 이름 클릭 시 팝오버.
   * 사용: <ProfileCard userId={id} name={name} tenantSlug={slug} />
   * employee_profiles 데이터가 있으면 직책/연락처 표시.
   */
  import { createRigelBrowserClient } from '$lib/client/supabase';

  interface Props {
    userId: string;
    name: string;
    tenantSlug: string;
  }

  let { userId, name, tenantSlug }: Props = $props();

  let open = $state(false);
  let loaded = $state(false);
  let profile = $state<{
    job_title: string | null;
    job_position: string | null;
    phone_mobile: string | null;
    phone_office: string | null;
  } | null>(null);

  async function loadProfile() {
    if (loaded) return;
    loaded = true;
    const supabase = createRigelBrowserClient();
    const { data } = await supabase
      .from('employee_profiles')
      .select('job_title, job_position, phone_mobile, phone_office')
      .eq('user_id', userId)
      .maybeSingle();
    profile = data;
  }

  function toggle() {
    open = !open;
    if (open) loadProfile();
  }
</script>

<svelte:window onclick={() => (open = false)} />

<span class="relative inline-block">
  <button
    type="button"
    class="text-sm text-blue-600 hover:underline cursor-pointer"
    onclick={(e) => { e.stopPropagation(); toggle(); }}
  >
    {name}
  </button>

  {#if open}
    <div
      class="absolute left-0 top-full z-20 mt-1 w-56 rounded-lg border bg-white p-3 shadow-lg"
      role="dialog"
      onclick={(e) => e.stopPropagation()}
    >
      <p class="font-medium text-sm">{name}</p>
      {#if profile}
        {#if profile.job_position || profile.job_title}
          <p class="text-xs text-gray-500 mt-0.5">
            {[profile.job_position, profile.job_title].filter(Boolean).join(' / ')}
          </p>
        {/if}
        {#if profile.phone_mobile}
          <p class="text-xs text-gray-500 mt-1">휴대폰: {profile.phone_mobile}</p>
        {/if}
        {#if profile.phone_office}
          <p class="text-xs text-gray-500">사무실: {profile.phone_office}</p>
        {/if}
      {:else if loaded}
        <p class="text-xs text-gray-400 mt-1">프로필 정보 없음</p>
      {:else}
        <p class="text-xs text-gray-400 mt-1">로딩...</p>
      {/if}
      <a
        href={`/t/${tenantSlug}/my/profile`}
        class="mt-2 block text-xs text-blue-600 hover:underline"
      >
        프로필 보기
      </a>
    </div>
  {/if}
</span>
