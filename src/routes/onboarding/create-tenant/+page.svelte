<script lang="ts">
  import { enhance } from '$app/forms';
  import { untrack } from 'svelte';

  let { form } = $props();
  let submitting = $state(false);

  // Capture prefill values once (untrack silences state_referenced_locally warning)
  let nameValue = $state(untrack(() => form?.values?.name ?? ''));
  let slugValue = $state(untrack(() => form?.values?.slug ?? ''));
  let slugTouched = $state(false);

  function suggestSlug(name: string): string {
    return name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 32);
  }

  $effect(() => {
    if (!slugTouched) {
      slugValue = suggestSlug(nameValue);
    }
  });
</script>

<div class="mx-auto max-w-md px-6 py-16">
  <h1 class="text-2xl font-bold tracking-tight">조직 만들기</h1>
  <p class="mt-2 text-sm text-gray-500">
    Rigel에서 첫 번째 조직을 만들어주세요. 조직 단위로 결재가 이루어집니다.
  </p>

  <form
    method="POST"
    class="mt-8 flex flex-col gap-4"
    use:enhance={() => {
      submitting = true;
      return async ({ update }) => {
        await update();
        submitting = false;
      };
    }}
  >
    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">조직명</span>
      <input
        type="text"
        name="name"
        required
        bind:value={nameValue}
        placeholder="예: Acme 주식회사"
        class="rounded border px-3 py-2"
        class:border-red-500={form?.errors?.fields?.name}
      />
      {#if form?.errors?.fields?.name}
        <span class="text-xs text-red-500">{form.errors.fields.name}</span>
      {/if}
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">주소 (slug)</span>
      <div class="flex items-center rounded border">
        <span class="px-3 py-2 text-sm text-gray-500 bg-gray-50 border-r">rigel.app/t/</span>
        <input
          type="text"
          name="slug"
          required
          bind:value={slugValue}
          onfocus={() => (slugTouched = true)}
          pattern="[a-z0-9][a-z0-9-]*[a-z0-9]"
          minlength="3"
          maxlength="32"
          class="flex-1 px-3 py-2 rounded-r"
          class:border-red-500={form?.errors?.fields?.slug}
        />
      </div>
      {#if form?.errors?.fields?.slug}
        <span class="text-xs text-red-500">{form.errors.fields.slug}</span>
      {:else}
        <span class="text-xs text-gray-500">소문자·숫자·하이픈만. 3~32자.</span>
      {/if}
    </label>

    <label class="flex items-start gap-2 rounded border bg-blue-50 px-3 py-2">
      <input type="checkbox" name="withSample" checked class="mt-1" />
      <span class="text-sm text-gray-700">
        <span class="font-medium">샘플 데이터 함께 생성</span>
        <span class="ml-1 text-xs text-gray-500">(체험용)</span>
        <br />
        <span class="text-xs text-gray-500">
          부서·게시판·공지·회의실·근무설정을 미리 채워 바로 둘러볼 수 있게 합니다. 나중에 관리 메뉴에서 수정·삭제 가능.
        </span>
      </span>
    </label>

    {#if form?.errors?.form}
      <p class="text-sm text-red-600">{form.errors.form}</p>
    {/if}

    <button
      type="submit"
      disabled={submitting}
      class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 disabled:opacity-50"
    >
      {submitting ? '생성 중…' : '조직 만들기'}
    </button>
  </form>
</div>
