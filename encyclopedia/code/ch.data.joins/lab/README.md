# JOIN 基数故障实验

实验注入三类错误：漏 ON 得到 4×4 笛卡尔积；LEFT 的右表状态条件放 WHERE 删除 D-03；技师 LEFT JOIN 后 COUNT(*) 把 T-03 错算为 1。

运行 `./verify.sh`。固定 oracle 不执行 SQL。
