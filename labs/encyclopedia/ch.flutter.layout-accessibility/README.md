# 实验：追踪 constraints-down / sizes-up

`boxes.yml` 描述一个 320 宽页面、16 像素双侧 padding、状态徽标和可伸缩标题。验证器计算标题获得的最大宽度，并检查所有报告尺寸都满足父约束。

```bash
./verify.sh
```

修改任一 child 的 `reported_width` 超出上限，可稳定复现合同失败；恢复后重跑。
