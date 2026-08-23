// 三条路由显式表达渲染所有权；平台缓存细节需在真实部署另行验证。
export default defineNuxtConfig({
  routeRules: {
    '/ssr': { ssr: true },
    '/ssg': { prerender: true },
    '/csr': { ssr: false },
  },
})

