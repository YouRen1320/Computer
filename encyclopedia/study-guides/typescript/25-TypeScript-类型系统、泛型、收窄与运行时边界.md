# TypeScript：类型系统、泛型、收窄与运行时边界

## 1. TypeScript 在运行前检查 JavaScript 的值关系

TypeScript 为 JavaScript 增加静态类型分析：

```ts
function calculateTotal(unitPriceCents: number, quantity: number): number {
  return unitPriceCents * quantity;
}

calculateTotal('1999', 3); // 编译期类型错误
```

类型帮助 IDE 和构建工具发现不一致，但最终运行的是 JavaScript。类型标注通常会被移除，浏览器不会自动检查 API JSON 是否符合 interface。

## 2. 类型描述可能的值集合

```ts
let count: number;
let label: string;
let active: boolean;
let nothing: null;
let missing: undefined;
```

把 `number` 理解为“所有 JavaScript number 值的集合”，把字面量类型 `'OPEN'` 理解为“只有这个值的集合”。联合类型是集合的并集：

```ts
type Status = 'OPEN' | 'IN_PROGRESS' | 'CLOSED';
```

这种心智模型能解释赋值、收窄和 never。

## 3. 类型推断减少重复标注

```ts
const title = 'Motor failure'; // 推断 string
let count = 0;                 // 推断 number
```

局部变量通常让 TypeScript 推断。函数公开参数、返回合同、模块边界和复杂对象适合显式类型。

过度标注会制造噪声；完全依赖推断又可能让公共 API 因实现细节意外变化。原则是“边界明确，局部简洁”。

## 4. const 的字面量推断比 let 更窄

```ts
const a = 'OPEN'; // 类型可能是 'OPEN'
let b = 'OPEN';   // 类型通常扩宽为 string
```

因为 const 绑定不会重新赋值，编译器可以保留更具体的字面量。对象属性仍可能修改，所以：

```ts
const order = { status: 'OPEN' }; // status 常推断为 string
```

需要保留全部字面量和只读关系可用 `as const`，但不要把整个应用数据都冻结成难修改类型。

## 5. 数组和元组表达不同结构

```ts
const ids: string[] = ['WO-1', 'WO-2'];
const pair: [string, number] = ['WO-1', 5];
```

数组长度可变、元素同类；元组在各位置有不同含义和已知结构。若位置含义不直观，命名对象通常更清楚：

```ts
type PriorityResult = { workOrderId: string; priority: number };
```

可用 `readonly string[]` 表示函数只读取数组，避免意外修改调用方集合。

## 6. 对象类型描述需要哪些字段

```ts
type WorkOrder = {
  id: string;
  title: string;
  status: Status;
  assigneeId?: string;
  readonly tenantId: string;
};
```

- `?` 表示字段可以不存在；
- `readonly` 阻止通过这个类型引用重新赋值，但不是运行时或深度不可变；
- 字段类型描述可接受值。

`assigneeId?: string` 与 `assigneeId: string | undefined` 在可否省略等细节上有区别，严格选项会让边界更清楚。

## 7. interface 和 type 都能描述对象合同

```ts
interface WorkOrderReader {
  findById(id: string): Promise<WorkOrder | null>;
}

type WorkOrderId = string;
type Result = Success | Failure;
```

两者大量能力重叠。常见选择：

- interface：对象形状、可扩展公共接口；
- type：联合、交叉、别名、映射和条件类型。

不要为风格争论制造重复类型。更重要的是所有权、命名和运行时边界。

## 8. 结构类型按形状兼容

```ts
type HasId = { id: string };

const full = { id: 'WO-42', title: '故障' };
const basic: HasId = full; // 可兼容
```

TypeScript 主要是结构类型：只要有需要的字段即可，不要求声明“implements HasId”。这适合 JavaScript 组合，也意味着两个语义不同但形状相同的 string ID 容易误传。

可用品牌类型或值对象增加区分，但应权衡复杂度。

## 9. 可选字段和 null 要按 API 合同区分

```ts
type Update = {
  assigneeId?: string | null;
};
```

可能表达：

- 字段缺失：不修改；
- `null`：清空负责人；
- string：设置负责人。

若业务没有这三种语义，就不要无意允许。开启 `strictNullChecks` 后，null/undefined 不再随便赋给 string，能减少大量运行错误。

## 10. 函数类型描述参数和结果

```ts
type PriorityCalculator = (input: PriorityInput) => number;

function apply(
  input: PriorityInput,
  calculate: PriorityCalculator,
): number {
  return calculate(input);
}
```

回调参数类型可由上下文推断。异步函数结果用 `Promise<T>`：

```ts
async function load(): Promise<WorkOrder[]> { ... }
```

`void` 表示调用者不使用返回值，不等同运行时函数绝对不能返回任何东西。

## 11. any 关闭检查，unknown 要求先确认

```ts
let unsafe: any;
unsafe.foo.bar(); // 编译器放弃保护

let value: unknown;
value.foo; // 错误，必须先收窄
```

外部输入、catch error 和未解析 JSON 更适合 unknown。`any` 会沿调用链扩散，使后续类型看似正常但实际无检查。

迁移旧项目可暂时使用局部 any，但应在边界尽快收口，并记录原因。

## 12. 收窄是在某条流程上排除不可能类型

```ts
function format(value: string | number): string {
  if (typeof value === 'number') {
    return value.toFixed(2);
  }
  return value.trim();
}
```

在 if 分支内，TypeScript 知道 value 是 number；之后剩下 string。可用的证据包括：

- `typeof`；
- `instanceof`；
- `in`；
- 相等检查；
- 真值检查（注意 0/空字符串）；
- 判别字段；
- 自定义 type guard。

## 13. 判别联合让状态与字段保持一致

```ts
type LoadState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: WorkOrder[] }
  | { status: 'error'; error: ApiError };
```

在 `status === 'success'` 分支中，data 一定存在。比以下松散对象更安全：

```ts
type WeakState = {
  loading: boolean;
  data?: WorkOrder[];
  error?: Error;
};
```

后者允许 loading=true、data 和 error 同时存在等矛盾状态。

## 14. never 表示没有任何可能值

穷尽检查：

```ts
function label(status: Status): string {
  switch (status) {
    case 'OPEN': return '待处理';
    case 'IN_PROGRESS': return '处理中';
    case 'CLOSED': return '已关闭';
    default: {
      const unreachable: never = status;
      return unreachable;
    }
  }
}
```

以后给 Status 新增值，未处理分支会在编译期暴露。never 也可表示永不正常返回的函数。

## 15. 类型断言不是运行时验证

```ts
const order = JSON.parse(text) as WorkOrder;
```

`as WorkOrder` 只是告诉编译器“相信我”，不会检查 id、status 是否存在。若数据不符合，错误会在更远处发生。

断言适合编译器无法看见但程序已由其他可靠机制保证的局部事实。外部网络、localStorage 和 postMessage 数据必须实际解析验证。

## 16. 非空断言也只是移除编译器警告

```ts
const form = document.querySelector('form')!;
```

DOM 真没有 form 时，运行仍会失败。更清楚：

```ts
const form = document.querySelector('form');
if (!(form instanceof HTMLFormElement)) {
  throw new Error('缺少表单');
}
```

`!` 应只用于有稳定外部不变量、且检查会造成无意义重复的局部位置。

## 17. 自定义 Type Guard 把运行检查告诉编译器

```ts
function isWorkOrder(value: unknown): value is WorkOrder {
  if (typeof value !== 'object' || value === null) return false;
  return 'id' in value && typeof value.id === 'string';
}
```

示例只检查 id，不能宣称验证了完整 WorkOrder。手写 guard 很容易漏嵌套字段、联合和错误路径；大型边界更适合 schema 库。

Predicate 的声明必须与实现一致，否则它会像类型断言一样制造假安全。

## 18. 泛型描述“类型之间的关系”

```ts
function first<T>(items: readonly T[]): T | undefined {
  return items[0];
}
```

输入是 T 数组，返回 T 或 undefined。调用 `first<string>` 时关系得到 string。

泛型不是为了把所有类型换成单字母；只有需要保留输入输出关系或复用结构时使用。若函数只接受 WorkOrder，就直接写 WorkOrder。

## 19. 泛型约束规定最低能力

```ts
function indexById<T extends { id: string }>(items: readonly T[]): Map<string, T> {
  return new Map(items.map(item => [item.id, item]));
}
```

T 可以有更多字段，但至少有 string id。约束不是把 T 变成只有 id，返回仍保留具体类型。

多个过度灵活泛型会让错误信息难读。公共 API 应让调用者不必理解复杂类型体操。

## 20. keyof 和索引访问保持字段关系

```ts
function get<T, K extends keyof T>(object: T, key: K): T[K] {
  return object[key];
}
```

若 key 是 `'status'`，返回类型就是对应字段类型。这比 `key: string → any` 保留更多信息。

`keyof` 反映静态已知键，不证明运行时对象没有额外字段。

## 21. 常用工具类型是已有类型的转换

```ts
Partial<WorkOrder>          // 所有字段可选
Required<WorkOrder>         // 所有字段必选
Readonly<WorkOrder>         // 顶层只读
Pick<WorkOrder, 'id' | 'status'>
Omit<WorkOrder, 'tenantId'>
Record<Status, string>
```

`Partial<WorkOrder>` 不自动等于合法更新 DTO：有些字段不可改，null/缺失语义也不同。业务输入类型应明确设计，再适量复用工具类型。

## 22. 映射类型遍历键构造新类型

```ts
type Nullable<T> = {
  [K in keyof T]: T[K] | null;
};
```

可以添加/移除 readonly 和可选修饰符、重映射键。它适合库和重复结构，但过度嵌套会让领域合同难读。

如果一个明确 interface 更容易理解，就不必用高级类型炫技。

## 23. 条件类型按类型关系选择结果

```ts
type ElementOf<T> = T extends readonly (infer U)[] ? U : T;
```

它类似类型层的条件，并可用 infer 提取部分。联合类型上的分布行为、递归深度等容易复杂化，属于需要时查询。

业务项目主要要能读懂库类型错误，不需要把每个 DTO 都写成条件类型谜题。

## 24. overload 表达有限的调用形式

```ts
function parse(value: string): WorkOrder;
function parse(value: ArrayBuffer): WorkOrder;
function parse(value: string | ArrayBuffer): WorkOrder {
  // 实现
}
```

调用者看到 overload，最后实现签名不是额外公开形式。若输入输出能通过联合和泛型清楚表达，优先用简单方案；大量 overload 会增加维护成本。

## 25. satisfies 检查形状同时保留具体推断

```ts
const labels = {
  OPEN: '待处理',
  IN_PROGRESS: '处理中',
  CLOSED: '已关闭',
} satisfies Record<Status, string>;
```

它验证 key/value 合同，又不把变量强行扩宽为通用 Record。适合配置表和穷尽映射。

`as` 是断言，`satisfies` 是检查，两者方向不同。

## 26. 模块边界应导出稳定类型

```ts
export type WorkOrderSummary = { ... };
export interface WorkOrderReader { ... }
```

不要导出组件内部所有响应式实现类型或数据库完整实体。模块公开类型是合同，修改会影响消费者。

使用 `import type` 可明确只在类型层依赖，并帮助某些构建配置避免不必要运行时导入。

## 27. API JSON 必须先当 unknown

```ts
const response = await fetch('/api/work-orders/42');
const raw: unknown = await response.json();
const order = WorkOrderSchema.parse(raw);
```

Schema 库在运行时验证，并可推导 TypeScript 类型。边界包括：

- HTTP 响应和请求；
- URL/query；
- localStorage；
- postMessage；
- 环境变量；
- 第三方 SDK；
- 用户上传文件解析结果。

验证后，内部代码才可依赖不变量。

## 28. Schema 需要决定拒绝、转换和默认值

字符串 `'3'` 是否转换为 number？未知字段是删除、保留还是拒绝？空字符串是否变 null？这些都是合同，不是库默认值越方便越好。

建议：

- 对 API 输入避免隐式宽松转换；
- 错误包含稳定字段路径和代码；
- 默认值由明确业务层设置；
- 日期仍需解析为确定语义；
- 校验与规范化步骤可区分。

## 29. 编译器严格选项让类型更可信

推荐以 `strict` 为基础，并按项目理解：

- `noUncheckedIndexedAccess`：索引访问可能 undefined；
- `exactOptionalPropertyTypes`：可选字段缺失语义更精确；
- `noImplicitOverride`：覆盖父方法需显式；
- `useUnknownInCatchVariables`：catch 变量按 unknown；
- `noFallthroughCasesInSwitch` 等控制流检查。

旧项目开启会有迁移成本，应分批修复真实风险，不用 `as any` 一次性消音。

## 30. 类型检查、lint、测试和构建各证明不同事情

```text
tsc / vue-tsc：静态类型关系
ESLint：代码模式与规则
单元/组件测试：特定运行行为
构建：工具能产出制品
浏览器/端到端：真实集成路径
```

类型通过不证明 API 真符合接口，也不证明按钮可访问；测试通过也不证明未覆盖路径。验证要对应声明风险。

## 31. 常见类型异味

- 到处 `any`；
- 网络 JSON 直接 `as Model`；
- 一个类型同时表示创建输入、数据库对象、API 响应和编辑草稿；
- 所有字段 `?`；
- 用 boolean 组合表示互斥状态；
- 巨型条件类型让错误不可读；
- 非空断言铺满代码；
- 为避错把合法联合扩宽成 string。

类型系统的目的不是零红线，而是让无效状态更难表示、边界更容易审查。

## 32. 这篇的整体地图

```text
JavaScript 值
  → TypeScript 用静态类型描述可能集合
  → 联合 + 控制流收窄表达分支
  → 判别联合让状态与字段一致
  → 泛型保留输入输出关系
  → 工具/映射类型复用结构
  → 外部 unknown 经运行时 schema 才进入可信内部
  → strict + lint + tests 分层验证
```

必须掌握：类型在运行时通常不存在；unknown 比 any 保留检查；`as` 和 `!` 不验证事实；判别联合能排除矛盾状态；泛型用于关系而不是装饰；API JSON 必须运行时校验。

装饰器类型、声明合并、复杂条件类型和库作者级类型技巧属于“需要时查询”。
