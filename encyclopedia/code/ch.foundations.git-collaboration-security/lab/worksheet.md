# Git 预测与诊断单

运行前填写：

1. 新建 `work-order.txt` 时 porcelain 状态是什么？
2. add 后是什么？add 后再次修改为何是两列都有状态？
3. 普通 diff 与 cached diff 分别比较哪两层？
4. main 与 feature 修改同一行，merge 的退出状态和未合并状态是什么？
5. 最终结果如何证明保留了双方规则？
6. 已提交的 `local.env` 加入 `.gitignore` 后为何仍报告？
7. `git rm --cached` 对 index、工作树和旧提交分别产生什么影响？
8. 若占位符换成真实 Token，第一动作是什么？哪些动作不能替代它？
9. 为什么本实验不添加 remote、不读取个人 `.gitconfig`、不运行 hooks？

保留首版错误预测。通过后记录一个误解、一条可迁移规则及第 2、7、21 天检索日期。
