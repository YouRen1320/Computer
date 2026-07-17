<script setup lang="ts">
import { nextTick, ref, shallowRef, watch } from 'vue'
const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ close: [] }>()

// Responsibility: preserve dialog semantics and interaction context across Teleport and v-if updates.
const panel = ref<HTMLElement | null>(null)
const field = ref<HTMLInputElement | null>(null)
const error = ref('')
const status = ref('')
const returnTarget = shallowRef<HTMLElement | null>(null)

watch(() => props.open, async (open, previous) => {
  if (open) {
    returnTarget.value = document.activeElement instanceof HTMLElement ? document.activeElement : null
    await nextTick()
    field.value?.focus()
  } else if (previous) {
    await nextTick()
    // Important side effect: restore the user's pre-dialog keyboard position after removal.
    returnTarget.value?.focus()
  }
}, { immediate: true })

function close() { emit('close') }
function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') { event.preventDefault(); close(); return }
  if (event.key !== 'Tab' || !panel.value) return
  // Non-obvious mapping: marked controls in DOM order define both forward and reverse wrap targets.
  const controls = [...panel.value.querySelectorAll<HTMLElement>('[data-focus]')]
  const first = controls[0]
  const last = controls.at(-1)
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() }
  if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
}

async function submit() {
  error.value = ''
  status.value = ''
  if (!field.value?.value.trim()) { error.value = '标题不能为空'; await nextTick(); field.value?.focus(); return }
  // Data source: this exercise simulates the async save boundary with a resolved Promise.
  await Promise.resolve()
  status.value = `保存成功：${field.value.value.trim()}`
}
</script>

<template>
  <Teleport to="body">
    <section v-if="open" ref="panel" role="dialog" aria-modal="true" aria-labelledby="dialog-title" @keydown="onKeydown">
      <h2 id="dialog-title">登记工单</h2>
      <label for="title">工单标题</label>
      <input id="title" ref="field" data-focus :aria-describedby="error ? 'title-error' : undefined">
      <p v-if="error" id="title-error" role="alert">{{ error }}</p>
      <p role="status" aria-live="polite">{{ status }}</p>
      <button type="button" data-focus @click="submit">保存</button>
      <button type="button" data-focus aria-label="关闭登记工单弹层" @click="close">取消</button>
    </section>
  </Teleport>
</template>
