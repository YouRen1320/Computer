# 切点、代理类型与自调用实验

实验直接构造 JDK 与 CGLIB Spring AOP proxy，验证透明计时、外部/内部调用差异，以及类代理的 final/private 边界。所有计时来自确定性时钟，无 sleep。

唯一入口 `./verify.sh` 离线执行十一项验收；不涉及 AspectJ weaving、Boot 完整自动代理或生产性能。
