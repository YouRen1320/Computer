<script setup lang="ts">
import { nextTick, ref, shallowRef, watch } from 'vue'

interface SaveGateway { save(input: { title: string }): Promise<void> }
const props = defineProps<{ open: boolean; gateway: SaveGateway }>()
const emit = defineEmits<{ close: []; saved: [payload: { title: string }] }>()

// Responsibility: keep modal semantics, keyboard containment, validation, announcements, and focus recovery together.
const panel = ref<HTMLElement | null>(null)
const titleInput = ref<HTMLInputElement | null>(null)
const title = ref('')
const error = ref('')
const statusMessage = ref('')
const saving = ref(false)
const returnTarget = shallowRef<HTMLElement | null>(null)

watch(() => props.open, async (isOpen, wasOpen) => {
  if (isOpen) {
    // Important side effect: capture the invoking control before Teleport content receives focus.
    returnTarget.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
    error.value = ''
    statusMessage.value = ''
    await nextTick()
    titleInput.value?.focus()
  } else if (wasOpen) {
    await nextTick()
    returnTarget.value?.focus()
  }
}, { immediate: true })

function requestClose() {
  if (!saving.value) emit('close')
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    requestClose()
    return
  }
  if (event.key !== 'Tab' || !panel.value) return
  // Non-obvious mapping: data attributes define the ordered focus ring independently of CSS/layout selectors.
  const focusable = [...panel.value.querySelectorAll<HTMLElement>('[data-dialog-focus]:not([disabled])')]
  if (focusable.length === 0) return
  const first = focusable[0]
  const last = focusable[focusable.length - 1]
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}

async function submit() {
  error.value = ''
  statusMessage.value = ''
  if (!title.value.trim()) {
    error.value = '请输入工单标题'
    await nextTick()
    titleInput.value?.focus()
    return
  }
  saving.value = true
  try {
    // Data source: the injected gateway is the only asynchronous persistence boundary.
    await props.gateway.save({ title: title.value.trim() })
    statusMessage.value = `已保存工单：${title.value.trim()}`
    emit('saved', { title: title.value.trim() })
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存失败，请重试'
    await nextTick()
    titleInput.value?.focus()
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="backdrop">
      <section
        ref="panel"
        class="dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="work-order-dialog-title"
        aria-describedby="work-order-dialog-help"
        @keydown="onKeydown"
      >
        <h2 id="work-order-dialog-title">新建工单</h2>
        <p id="work-order-dialog-help">所有字段均为必填。保存完成后会在本弹层内提示。</p>
        <label for="work-order-title">工单标题</label>
        <input
          id="work-order-title"
          ref="titleInput"
          v-model="title"
          data-dialog-focus
          :aria-invalid="Boolean(error)"
          :aria-describedby="error ? 'work-order-title-error' : undefined"
        >
        <p v-if="error" id="work-order-title-error" role="alert">{{ error }}</p>
        <p class="status" role="status" aria-live="polite">{{ statusMessage }}</p>
        <div class="actions">
          <button type="button" data-dialog-focus :disabled="saving" @click="submit">
            {{ saving ? '正在保存' : '保存工单' }}
          </button>
          <button type="button" data-dialog-focus :disabled="saving" aria-label="关闭新建工单弹层" @click="requestClose">取消</button>
        </div>
      </section>
    </div>
  </Teleport>
</template>
