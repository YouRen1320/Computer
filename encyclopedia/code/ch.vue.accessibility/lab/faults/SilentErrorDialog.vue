<script setup lang="ts">
import { ref } from 'vue'
// Injected fault: conditional error text has no alert/live semantics or field association.
const error = ref('保存失败')
</script>
<template><label>标题<input></label><p v-if="error">{{ error }}</p></template>
