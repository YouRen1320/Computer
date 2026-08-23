# Worksheet

| case | 预计 affected rows | 预计 RETURNING/约束 | 实际 | COMMIT/ROLLBACK |
| --- | ---: | --- | --- | --- |
| INSERT D-04 |  |  |  |  |
| UPDATE D-01 version=3 |  |  |  |  |
| 再用 version=3 |  |  |  |  |
| DELETE ACTIVE D-02 |  |  |  |  |
| UPSERT SN-002 |  |  |  |  |
| UPDATE 无 WHERE |  |  |  |  |
| DELETE 无 WHERE |  |  |  |  |
| UPSERT 改 device_id |  |  |  |  |

每例记录输入、同谓词预览、预期/实际行数、返回键和最终事务决定。零行没有异常也必须判业务结果。
