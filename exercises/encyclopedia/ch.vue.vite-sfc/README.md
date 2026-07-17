# 公开练习：修复根组件挂载契约

starter 的 `index.html` 提供 `#factorycare-root`，但 `main.ts` 仍挂到 `#app`。生产构建可能不发现这个运行期契约错误，因此验证器会输出确定性红灯：

```sh
./verify.sh
```

只修改 `src/main.ts`，让选择器与已有宿主一致。不得改 HTML 宿主、放宽验证器、删除根组件或把成功标记直接写进 `index.html`。修复后验证器应输出 `EXERCISE PASS`。
