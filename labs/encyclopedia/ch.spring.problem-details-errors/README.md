# FactoryCare 四类错误合同实验

实验用十条可重放断言固定四类失败的 status、type、title、detail、instance、code、traceId，并证明校验 errors 排序、未知异常对外脱敏且对内保留 cause、正常响应不受 advice 影响。

先写请求矩阵，再运行 `./verify.sh`。本实验不实现认证授权、真实日志平台、数据库事务、Boot `/error` 或反向代理。

验证器要求 JDK 25、Maven 3.9.16，并完全离线运行。
