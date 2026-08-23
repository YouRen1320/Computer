<script setup lang="ts">
import { nextTick, ref, shallowRef, watch } from 'vue'

const props = defineProps<{ open: boolean; save: (title: string) => Promise<void> }>()
const emit = defineEmits<{ close: []; saved: [title: string] }>()

// Responsibility: implement the semantic, focus, keyboard, and announcement contract under test.
const dialog = ref<HTMLElement | null>(null)
const field = ref<HTMLInputElement | null>(null)
const title = ref('')
const error = ref('')
const message = ref('')
const busy = ref(false)
const returnTarget = shallowRef<HTMLElement | null>(null)

watch(() => props.open, async (open, previous) => {
  if (open) {
    returnTarget.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
    await nextTick()
    field.value?.focus()
  } else if (previous) {
    await nextTick()
    // Important side effect: the invoking control regains focus only after the teleported subtree leaves.
    returnTarget.value?.focus()
  }
}, { immediate: true })

function close() { if (!busy.value) emit('close') }
function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') { event.preventDefault(); close(); return }
  if (event.key !== 'Tab' || !dialog.value) return
  // Non-obvious mapping: DOM order of marked controls defines the focus cycle.
  const controls = [...dialog.value.querySelectorAll<HTMLElement>('[data-focus]:not([disabled])')]
  const first = controls[0]
  const last = controls.at(-1)
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() }
  if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
}

async function submit() {
  error.value = ''
  message.value = ''
  if (!title.value.trim()) { error.value = '标题不能为空'; await nextTick(); field.value?.focus(); return }
  busy.value = true
  try {
    // Data source: save is the injected persistence boundary; visible states remain real.
    await props.save(title.value.trim())
    message.value = `保存成功：${title.value.trim()}`
    emit('saved', title.value.trim())
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存失败'
    await nextTick()
    field.value?.focus()
  } finally { busy.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="backdrop">
      <section ref="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title" aria-describedby="dialog-help" @keydown="onKeydown">
        <h2 id="dialog-title">登记维修工单</h2>
        <p id="dialog-help">填写标题后保存，按 Escape 可取消。</p>
        <label for="title">工单标题</label>
        <input id="title" ref="field" v-model="title" data-focus :aria-invalid="Boolean(error)" :aria-describedby="error ? 'title-error' : undefined">
        <p v-if="error" id="title-error" role="alert">{{ error }}</p>
        <p role="status" aria-live="polite">{{ message }}</p>
        <button type="button" data-focus :disabled="busy" @click="submit">{{ busy ? '保存中' : '保存' }}</button>
        <button type="button" data-focus :disabled="busy" aria-label="关闭登记维修工单弹层" @click="close">取消</button>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.backdrop { position: fixed; inset: 0; display: grid; place-items: center; background: rgb(0 0 0 / 65%); }
section { width: min(30rem, calc(100% - 2rem)); padding: 1.5rem; background: white; color: #172033; }
button, input { min-height: 44px; }
:focus-visible { outline: 3px solid #ff8a00; outline-offset: 3px; }
@media (prefers-reduced-motion: reduce) { * { animation-duration: .01ms !important; transition-duration: .01ms !important; } }
</style>
