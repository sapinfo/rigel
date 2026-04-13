<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Editor } from '@tiptap/core';
  import StarterKit from '@tiptap/starter-kit';
  import Link from '@tiptap/extension-link';
  import Placeholder from '@tiptap/extension-placeholder';

  type Props = {
    value: string;
    placeholder?: string;
    readonly?: boolean;
    onChange: (html: string) => void;
  };

  let { value, placeholder = '내용을 입력하세요', readonly = false, onChange }: Props = $props();

  let element = $state<HTMLDivElement | null>(null);
  let editor = $state<Editor | null>(null);

  onMount(() => {
    if (!element) return;
    editor = new Editor({
      element,
      extensions: [
        StarterKit,
        Link.configure({ openOnClick: false }),
        Placeholder.configure({ placeholder })
      ],
      content: value || '',
      editable: !readonly,
      onUpdate: ({ editor: e }) => {
        onChange(e.getHTML());
      }
    });
  });

  onDestroy(() => {
    editor?.destroy();
  });
</script>

{#if !readonly && editor}
  <div class="mb-1 flex flex-wrap gap-0.5 border-b pb-1">
    <button type="button" onclick={() => editor?.chain().focus().toggleBold().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('bold')}>
      <strong>B</strong>
    </button>
    <button type="button" onclick={() => editor?.chain().focus().toggleItalic().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('italic')}>
      <em>I</em>
    </button>
    <button type="button" onclick={() => editor?.chain().focus().toggleStrike().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('strike')}>
      <s>S</s>
    </button>
    <span class="mx-1 border-r"></span>
    <button type="button" onclick={() => editor?.chain().focus().toggleHeading({ level: 2 }).run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('heading', { level: 2 })}>
      H2
    </button>
    <button type="button" onclick={() => editor?.chain().focus().toggleHeading({ level: 3 }).run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('heading', { level: 3 })}>
      H3
    </button>
    <span class="mx-1 border-r"></span>
    <button type="button" onclick={() => editor?.chain().focus().toggleBulletList().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('bulletList')}>
      UL
    </button>
    <button type="button" onclick={() => editor?.chain().focus().toggleOrderedList().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('orderedList')}>
      OL
    </button>
    <span class="mx-1 border-r"></span>
    <button type="button" onclick={() => editor?.chain().focus().toggleBlockquote().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100" class:bg-gray-200={editor?.isActive('blockquote')}>
      ""
    </button>
    <button type="button" onclick={() => editor?.chain().focus().setHorizontalRule().run()}
      class="rounded px-2 py-0.5 text-xs hover:bg-gray-100">
      ─
    </button>
  </div>
{/if}

<div bind:this={element} class="prose prose-sm max-w-none rounded border p-3 focus-within:ring-1 focus-within:ring-blue-500 {readonly ? 'bg-gray-50' : ''}"></div>

<style>
  :global(.tiptap) {
    outline: none;
    min-height: 120px;
  }
  :global(.tiptap p.is-editor-empty:first-child::before) {
    color: #adb5bd;
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
  }
</style>
