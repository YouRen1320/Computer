<script setup lang="ts">
// Responsibility: render a redirect target without granting access to protected data.
defineProps<{ redirect: string }>()
</script>

<template><article><h1 tabindex="-1" data-page-title>请先登录</h1><p data-testid="redirect-target">登录后返回：{{ redirect }}</p></article></template>

