# JavaScript：集合、对象、原型与模块

## 1. 数组用于有顺序的一组值

```js
const priorities = [2, 5, 3];
priorities[0];      // 2
priorities.length;  // 3
```

索引从 0 开始。访问不存在索引得到 undefined，通常不会自动报错，因此边界错误可能静默传播。

数组可以混合类型，但业务集合应保持一致结构，TypeScript 也更容易帮助。

## 2. 修改型和非修改型数组操作要分清

修改原数组：

```text
push、pop、shift、unshift、splice、sort、reverse
```

返回新数组或新值：

```text
map、filter、slice、concat、toSorted、toReversed、reduce
```

是否修改不是好坏之分，但共享状态和 UI 响应式代码中，意外原地修改会让数据流难追踪。调用前应知道方法合同。

## 3. map、filter、find、some 和 every 各有问题类型

```js
orders.map(order => order.id);                 // 每项转换
orders.filter(order => order.priority === 5); // 保留匹配项
orders.find(order => order.id === targetId);  // 第一个匹配值或 undefined
orders.some(order => order.overdue);           // 是否至少一个
orders.every(order => order.valid);            // 是否全部
```

不要用 `map` 只为了执行副作用而丢掉返回数组；这种情况用 `for...of` 或 `forEach` 更能表达意图。

## 4. reduce 把多项累积成一个结果

```js
const total = orders.reduce(
  (sum, order) => sum + order.amountCents,
  0,
);
```

初始值 `0` 明确空数组结果和累积类型。没有初始值时，空数组会抛异常，并把第一项当初始累积值。

若 reduce 同时构建五种统计、修改外部状态并嵌套条件，普通循环可能更清楚。函数式写法不是越短越好。

## 5. sort 默认按字符串比较并修改原数组

```js
[2, 10, 3].sort(); // 可能得到 [10, 2, 3]
```

数字比较要提供 comparator：

```js
numbers.toSorted((a, b) => a - b);
```

`sort` 修改原数组，`toSorted` 返回新数组。排序对象时要处理相等、null、语言规则和稳定的次级排序。

```js
orders.toSorted((a, b) => b.priority - a.priority || a.id.localeCompare(b.id));
```

## 6. 解构从数组或对象取出字段

```js
const [first, second] = priorities;
const { id, status } = order;
```

可重命名和默认值：

```js
const { status: currentStatus, title = '未命名' } = order;
```

默认值只在字段是 undefined 时使用，不会替换 null。深层解构过多会把输入假设藏在一行中，外部数据仍需验证。

## 7. Spread 只做浅复制

```js
const next = { ...order, status: 'CLOSED' };
const copy = [...orders];
```

顶层容器是新的，嵌套对象仍共享：

```js
const copy = { ...order };
copy.assignee.name = 'A';
// order.assignee.name 也可能变化
```

不要把 spread 当深拷贝。深层数据更适合规范化结构、针对变化路径逐层复制，或在明确可序列化边界使用 `structuredClone`。

## 8. 普通对象保存字符串或 Symbol 键到值的映射

```js
const order = {
  id: 'WO-42',
  status: 'OPEN',
  close() {
    this.status = 'CLOSED';
  },
};
```

访问：

```js
order.status
order['status']
order[fieldName]
```

方括号适合动态键。外部键用于对象时要警惕原型污染和保留键，Map 或无原型对象可能更合适。

## 9. 属性有拥有者、可枚举性和描述符

`Object.keys` 只返回对象自身、可枚举、字符串键。`for...in` 会沿原型链遍历可枚举属性。

```js
Object.hasOwn(order, key)
```

可判断是否为自身属性。不要用 `if (order[key])` 判断字段存在，因为合法值可能是 0、false 或空字符串。

属性描述符的 writable、enumerable、configurable 等细节需要时查询。

## 10. Map 适合任意键和频繁增删查

```js
const byId = new Map();
byId.set(order.id, order);
byId.get(order.id);
byId.has(order.id);
byId.delete(order.id);
```

Map 键可以是对象，保留插入顺序，并有明确 size。普通对象适合有固定字段的记录；Map 适合运行时动态映射。

Map 不会直接按 JSON 默认序列化，跨网络前要转换为明确结构。

## 11. Set 保存不重复的值

```js
const tags = new Set(['urgent', 'safety', 'urgent']);
tags.size; // 2
```

常用于去重和成员判断：

```js
const uniqueIds = [...new Set(ids)];
```

对象去重按引用身份，不按内容：两个 `{ id: 1 }` 是两个不同成员。按业务 ID 去重应显式构建 Map 或 Set of IDs。

## 12. WeakMap 和 WeakSet 不阻止对象被回收

它们的键/成员必须是可弱引用对象，且不可枚举。适合为对象附加不应影响生命周期的元数据。

无法遍历不是缺陷，而是弱引用语义的一部分。普通业务集合、缓存列表和需要统计的内容通常使用 Map/Set。

## 13. 对象相等默认比较身份

```js
{} === {} // false

const a = { id: 1 };
const b = a;
a === b // true
```

若要比较业务值，应比较明确字段或使用经过定义的深比较函数。JSON.stringify 比较会受字段顺序、undefined、Date、Map、循环引用等影响，不是通用相等算法。

## 14. 原型是对象查找缺失属性时的后备链

访问 `object.method` 时：

```text
先看 object 自己有没有 method
  → 没有就看 object 的原型
  → 再看原型的原型
  → 直到 null
```

这叫 prototype chain。数组方法不复制在每个数组上，而是通过 `Array.prototype` 共享。

```js
Object.getPrototypeOf([]) === Array.prototype // true
```

## 15. 构造函数和 new 建立实例与原型关系

传统形式：

```js
function WorkOrder(id) {
  this.id = id;
}

WorkOrder.prototype.close = function () {
  this.status = 'CLOSED';
};

const order = new WorkOrder('WO-42');
```

`new` 大致创建对象、把原型连到构造函数 prototype、以新对象为 this 调用函数并返回对象。

现代 class 语法封装了这个模型，但底层仍是原型继承。

## 16. class 提供更清楚的对象语法

```js
class WorkOrder {
  #status = 'OPEN';

  constructor(id) {
    this.id = id;
  }

  close() {
    this.#status = 'CLOSED';
  }

  get status() {
    return this.#status;
  }
}
```

方法位于 prototype，实例字段位于每个对象。`#status` 是运行时私有字段，不等同 TypeScript 的仅编译期 private 语义。

class 适合有身份、行为和生命周期的对象；纯数据 DTO 不必全变 class。

## 17. this 由调用方式决定

```js
const order = {
  id: 'WO-42',
  show() { return this.id; },
};

order.show(); // this 是 order

const show = order.show;
show();       // 严格模式下 this 通常是 undefined
```

把方法脱离对象后，调用点变了，this 也变了。可用 `bind` 固定：

```js
const boundShow = order.show.bind(order);
```

箭头函数没有自己的 this，会使用创建位置的外层 this。

## 18. 不要在箭头函数中期待动态 this

```js
const order = {
  id: 'WO-42',
  show: () => this.id,
};
```

这个箭头的 this 不是 order。对象普通方法应使用方法语法；回调若需要保留外层实例 this，箭头函数适合：

```js
class List {
  items = [];
  load() {
    fetch('/api').then(data => {
      this.items = data;
    });
  }
}
```

## 19. 继承使用原型链，但组合常更简单

```js
class CriticalWorkOrder extends WorkOrder { ... }
```

继承适合稳定的“is-a”关系和可替换行为。若只是复用日志、校验或 API 客户端，用组合更清楚：

```js
const service = new WorkOrderService(repository, notifier);
```

深层 class 树容易让行为来源难追踪。JavaScript 对象也可通过函数和闭包组合能力，不必强行模仿 Java 类层次。

## 20. 原型污染来自不可信键修改继承对象

若把用户输入递归合并到普通对象，特殊键如 `__proto__`、`constructor`、`prototype` 可能改变原型链，影响其他对象。

防护：

- 不把不可信对象无条件深合并到配置；
- 使用维护良好的安全库并及时更新；
- 校验允许键；
- 动态字典用 Map 或 `Object.create(null)`；
- 不依赖继承属性做授权判断；
- 用 `Object.hasOwn` 检查自身字段。

## 21. JSON 是文本交换格式，不保留所有 JavaScript 类型

```js
const text = JSON.stringify({ id: 'WO-42' });
const value = JSON.parse(text);
```

JSON 支持对象、数组、字符串、数字、布尔和 null。它不会自然保留：

- undefined；
- function、Symbol；
- Map/Set；
- Date 的类型身份；
- BigInt；
- 原型和 class 方法；
- 循环引用。

解析后得到普通数据，仍要验证 schema；“JSON 能解析”不代表字段可信。

## 22. 模块让文件显式导入和导出依赖

```js
// priority.js
export function calculatePriority(input) { ... }

// app.js
import { calculatePriority } from './priority.js';
```

ES Modules（ESM）有自己的模块作用域，避免所有变量落到全局。导入是 live binding：导出方绑定变化时，导入方看到更新，但导入方不能随意重新赋值。

模块应围绕责任组织，不是一类一个文件或所有工具一个 `utils.js`。

## 23. 命名导出和默认导出

```js
export const parseOrder = ...;
export const validateOrder = ...;
```

命名导出在重构和自动导入时通常更清楚。默认导出允许导入方任意命名，适合模块有一个明确主值的情况。

团队可约定风格，但不要用巨大的 barrel 文件无差别重导出一切，它会隐藏模块边界并可能引入循环依赖。

## 24. 静态 import 和动态 import 用途不同

静态导入：

```js
import { formatDate } from './date.js';
```

在模块分析时确定，便于工具构建依赖图和 tree shaking。

动态导入：

```js
const module = await import('./heavy-report.js');
```

返回 Promise，适合按路由或功能懒加载。不要把所有导入都动态化，会让错误更晚出现、代码分割碎片化。

## 25. ESM 在浏览器和 Node 中有解析边界

浏览器原生模块需要可访问 URL，并遵守 CORS/MIME 等规则。Node 的 ESM 解析受 `package.json`、扩展名和包 exports 影响。

```json
{ "type": "module" }
```

可让 `.js` 按 ESM 解释。CommonJS 的 `require/module.exports` 与 ESM 不同，混用时要查看当前 Node 和包文档，不能靠复制随机配置。

## 26. 包管理器解决依赖版本和安装

`package.json` 声明项目元数据、脚本和依赖；lockfile 记录解析后的精确依赖图，使团队和 CI 更可重复。

```text
package.json：允许范围与直接依赖
pnpm-lock.yaml 等：一次具体解析结果
node_modules / store：已安装内容
```

依赖升级应审查变更和安全影响。不要删除 lockfile 再说“让它自己修好”，也不要在不同包管理器间混用多个 lockfile。

## 27. dependencies 和 devDependencies 表达运行责任

- `dependencies`：生产运行或打包输出所需；
- `devDependencies`：测试、lint、类型检查、构建等开发工具。

前端打包后依赖是否出现在服务器 `node_modules` 取决于构建方式；分类表达意图，不等于所有部署机制完全相同。

包的 `peerDependencies` 用于声明宿主应提供的兼容依赖，常见于插件和组件库，需要时查询。

## 28. scripts 是可重复命令入口

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "test": "vitest run",
    "typecheck": "vue-tsc --noEmit"
  }
}
```

团队和 CI 使用同一脚本，比每个人记一串不同参数可靠。脚本成功只证明对应命令通过，不能自动证明浏览器行为、无障碍和生产配置都正确。

## 29. 循环模块依赖会产生初始化问题

```text
A imports B
B imports A
```

ESM 可以描述循环，但某些绑定在对方访问时尚未初始化，或模块职责互相纠缠。解决方式通常是提取真正共同的稳定合同、反转依赖或合并本来不可分的模块，而不是改变 import 顺序碰碰运气。

## 30. 这篇的整体地图

```text
数组：有序集合与转换
Map / Set：动态映射与唯一成员
对象：固定字段与身份引用
  → 原型链提供共享行为
  → class 是原型模型的清楚语法
  → this 由调用方式决定
模块：显式 import/export 组织依赖
  → 包管理器 + lockfile 保持安装可重复
```

必须掌握：sort 会修改数组且默认按字符串；spread 是浅复制；对象相等比较身份；Map 和普通对象用途不同；class 底层仍是原型；this 看调用点；ESM 提供模块作用域和显式依赖。

属性描述符、Proxy、迭代协议和高级包 exports 属于“需要时查询”。
