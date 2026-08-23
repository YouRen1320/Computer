<script setup lang="ts">
import { onLaunch, onShow, onHide } from '@dcloudio/uni-app'

// 应用级副作用只保留脱敏轨迹，页面数据由具体页面拥有。
onLaunch(() => console.info('app:onLaunch'))
onShow(() => console.info('app:onShow'))
onHide(() => console.info('app:onHide'))
</script>

<style>
page {
  background: #f7f8fa;
}
</style>
