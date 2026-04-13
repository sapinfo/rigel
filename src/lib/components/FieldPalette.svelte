<script lang="ts">
  import type { FormFieldType } from '$lib/types/approval';

  const FIELD_TYPES: { type: FormFieldType; label: string; icon: string }[] = [
    { type: 'text', label: '텍스트', icon: 'Aa' },
    { type: 'textarea', label: '장문 텍스트', icon: '¶' },
    { type: 'richtext', label: '리치 텍스트', icon: '✎' },
    { type: 'number', label: '숫자', icon: '#' },
    { type: 'date', label: '날짜', icon: '📅' },
    { type: 'date-range', label: '기간', icon: '📅📅' },
    { type: 'select', label: '선택', icon: '▼' },
    { type: 'attachment', label: '첨부파일', icon: '📎' }
  ];

  type Props = {
    onAddField: (type: FormFieldType) => void;
  };

  let { onAddField }: Props = $props();
</script>

<div class="space-y-1">
  <h3 class="px-2 text-xs font-semibold uppercase text-gray-400">필드 추가</h3>
  {#each FIELD_TYPES as ft (ft.type)}
    <button
      type="button"
      class="flex w-full items-center gap-2 rounded px-3 py-2 text-sm hover:bg-gray-100"
      onclick={() => onAddField(ft.type)}
    >
      <span class="w-6 text-center text-xs">{ft.icon}</span>
      <span>{ft.label}</span>
    </button>
  {/each}
</div>
