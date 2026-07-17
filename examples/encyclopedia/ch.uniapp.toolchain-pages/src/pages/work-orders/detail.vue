<script setup lang="ts">
import { ref } from 'vue'
import { onLoad } from '@dcloudio/uni-app'

const workOrderId = ref('INVALID')

onLoad((query) => {
  // 路由 query 是不可信字符串；格式通过后服务端仍执行租户和权限校验。
  const candidate = String(query?.id ?? '').trim()
  workOrderId.value = /^WO-[0-9]{4,20}$/.test(candidate) ? candidate : 'INVALID'
})
</script>

<template>
  <view class="page">
    <text>工单：{{ workOrderId }}</text>
  </view>
</template>
