<script setup lang="ts">
import { ref, watch } from 'vue'
const props = defineProps<{ open: boolean }>()
const emit = defineEmits<{ close: [] }>()
const field = ref<HTMLInputElement | null>(null)
const error = ref('')

// Starter fault: focus runs before v-if/Teleport commit, and no return target is preserved.
watch(() => props.open, (open) => { if (open) field.value?.focus() })
function submit() { error.value = '标题不能为空' }
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="dialog">
      <h2>登记工单</h2>
      <input ref="field" placeholder="标题">
      <p v-if="error">{{ error }}</p>
      <button type="button" @click="submit">保存</button>
      <button type="button" @click="emit('close')">取消</button>
    </div>
  </Teleport>
</template>
