# 连接归还私有答案

答案用 try-with-resources 同时关闭 ResultSet、PreparedStatement 与 Connection；池代理的 close 把连接归还 Hikari。唯一入口 `./verify.sh` 必须离线全绿。
