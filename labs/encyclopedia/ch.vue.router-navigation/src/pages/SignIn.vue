<script setup lang="ts">
// Responsibility: display the intended return URL, not authorize the protected resource.
defineProps<{ redirect: string }>()
</script>

<template><article><h1>登录</h1><p data-testid="redirect">{{ redirect }}</p></article></template>

