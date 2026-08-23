# 资源路径与阻塞资源故障实验

`scenario.json` 固定保存基线、CSS 404 和 CSS 延迟三组观察。oracle 先证明故障确实红，再检查修复使用同一 URL/DOM/阶段预言重跑。实验的重点是指出第一可信证据，不是把所有慢页面都归因于 CSS。

```bash
./verify.sh
```

运行前可先填写 [worksheet.md](worksheet.md)。这里的毫秒值是合成夹具，只用于比较因果，不是生产性能门；真实故障需保存浏览器版本、HAR、截图和 Performance trace。
