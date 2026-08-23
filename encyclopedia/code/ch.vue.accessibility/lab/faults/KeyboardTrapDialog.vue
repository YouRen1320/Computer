<script setup lang="ts">
// Injected fault: every key is suppressed, so Escape cannot close and Tab cannot leave or cycle predictably.
function trap(event: KeyboardEvent) { event.preventDefault() }
</script>
<template><section role="dialog" @keydown="trap"><button>唯一控制</button></section></template>
