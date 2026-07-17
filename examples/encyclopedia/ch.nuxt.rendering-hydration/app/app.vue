<template>
  <!-- 根组件只提供稳定导航和页面出口，不读取浏览器专属状态。 -->
  <div>
    <nav aria-label="渲染模式"><NuxtLink to="/ssr">SSR</NuxtLink> <NuxtLink to="/ssg">SSG</NuxtLink> <NuxtLink to="/csr">CSR</NuxtLink></nav>
    <NuxtPage />
  </div>
</template>

