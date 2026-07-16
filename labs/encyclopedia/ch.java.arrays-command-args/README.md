# 实验：0、1、N、别名与二维边界

本实验验证数组章节的最低边界，而不是只演示一个三项正常案例。

| 场景 | 固定预期 |
| --- | --- |
| 空数组 | length=0，遍历 0 次 |
| 单项数组 | 首尾都是索引 0 的值 4 |
| 多项数组 | 最大值 5，第一个 4 在索引 2，紧急项 3 个 |
| 别名 | alias 修改后 original 同步为 5 |
| 独立复制 | copy 改为 9，original 仍为 5 |
| 二维数组 | 三行长度为 2、1、0 |
| 无参数 | count=0、max=NONE、sum=0 |
| 参数 3 5 2 | count=3、max=5、sum=10 |

```bash
cd labs/encyclopedia/ch.java.arrays-command-args
./verify.sh
```

验收要求：两组正常输出精确匹配；`java -ea` 输出 `assertions=14 passed`；把 length 当索引、空 args 读索引 0、二维行列错误三个探针都非零退出；最后出现 `LAB PASS`。
