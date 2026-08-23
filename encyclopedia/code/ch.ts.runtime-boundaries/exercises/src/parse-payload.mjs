// 故意错误：没有任何运行时 Schema，所有输入都被包装成成功结果。
export function parsePayload(input) {
  return { ok: true, value: input }
}

