# JSON 数据边界最小示例

这个 Java 25 离线示例只用 JDK API。`JsonSupport.java` 内的 parser 只支持本章固定扁平 object 的 string、number、null；它用于暴露映射决策，不是生产通用 JSON 库。

运行前预测 canonical JSON、UTF-8 中文、assignee 三态、unknown strict/ignore 和非法枚举：

```bash
./verify.sh
```

脚本用固定 build 文件往返八条输出，并要求非法 enum 独立进程失败。生产项目应改用 Maven 固定且受审计的成熟 mapper，保留同一组边界 fixtures。
