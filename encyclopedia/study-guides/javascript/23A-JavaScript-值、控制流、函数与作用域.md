# JavaScript：值、控制流、函数与作用域

## 1. JavaScript 源码由语句和表达式组成

表达式会产生一个值：

```js
price * quantity
status === 'OPEN'
user?.name ?? '未知用户'
```

语句让程序执行动作或控制流程：

```js
const total = price * quantity;
if (total > 10000) {
  console.log('需要审批');
}
```

理解“这里会得到什么值”和“这里会改变什么流程”，比机械记分号更重要。

## 2. JavaScript 值有不同类型

常见原始类型：

- `number`：普通数字，包括整数和小数；
- `bigint`：任意精度整数；
- `string`：文本；
- `boolean`：`true` / `false`；
- `undefined`：通常表示尚未提供；
- `null`：显式表示没有值；
- `symbol`：唯一标识用途。

对象类型包括普通对象、数组、函数、Map、Date 等。函数在 JavaScript 中也是可传递的对象。

```js
typeof 42          // 'number'
typeof '42'        // 'string'
typeof undefined   // 'undefined'
typeof null        // 历史原因得到 'object'
```

判断 null 应直接用 `value === null`，不要依赖 `typeof null`。

## 3. number 使用浮点表示，安全整数有边界

JavaScript 的普通 `number` 基于 IEEE 754 双精度浮点，因此：

```js
0.1 + 0.2 === 0.3 // false
```

它也只有一段安全整数范围。金额不能因为看起来是整数就无限安全。常见做法：

- 小范围金额用安全整数“分”并检查范围；
- 财务精度使用十进制库或后端明确合同；
- 大整数标识不要先转 number；
- 用 `Number.isSafeInteger` 检查必须精确的整数。

`bigint` 不能与 number 直接混算，也不能自然表示小数。

## 4. NaN 表示“本应是数字但计算失败”

```js
Number('abc') // NaN
```

`NaN` 与自身也不相等：

```js
NaN === NaN // false
```

正确检查：

```js
Number.isNaN(value)
```

全局 `isNaN` 会先做类型转换，容易产生意外。解析输入后还应检查有限值、整数范围和业务范围。

## 5. String、Number 和 Boolean 转换要显式理解

```js
Number('42')      // 42
Number('')        // 0
String(42)        // '42'
Boolean('false')  // true，因为非空字符串是真值
```

隐式转换会在运算符、条件和模板中出现：

```js
'total=' + 1 + 2 // 'total=12'
1 + 2 + ' total' // '3 total'
```

对外部输入应显式解析，再验证结果。不要因为 `Number(value)` 没抛异常就认为输入合法。

## 6. parseInt 和 Number 的接受范围不同

```js
Number('12px')       // NaN
parseInt('12px', 10) // 12
```

如果要求整个输入都是整数，`parseInt` 的宽松行为可能掩盖错误。可先按合同验证文本，再转换；或用 `Number` 后检查整数。

```js
const value = Number(text);
if (!Number.isInteger(value)) {
  throw new Error('必须是整数');
}
```

## 7. `===` 默认比 `==` 更容易推理

严格相等不做大范围类型转换：

```js
0 === false // false
'0' === 0   // false
```

宽松相等：

```js
0 == false  // true
'' == 0     // true
```

项目通常以 `===` / `!==` 为默认。`x == null` 有一个受控惯用语义：同时匹配 null 和 undefined，但如果团队采用它，应明确约定而不是到处混用。

`Object.is` 在 `NaN` 和正负零等少数边界上与 `===` 不同，需要时查询。

## 8. 真值和假值会影响条件

假值包括：

```text
false、0、-0、0n、''、null、undefined、NaN
```

其他值通常为真，包括空数组 `[]` 和空对象 `{}`。

```js
if (items) { ... } // 空数组也会进入
```

如果要判断数组有内容，应写 `items.length > 0`。不要把“存在”“非空”“非零”和“合法”都塞进一次真值判断。

## 9. `||` 和 `??` 的默认值语义不同

```js
const a = count || 10; // count=0 时得到 10
const b = count ?? 10; // 只有 null/undefined 时得到 10
```

数量 0、空字符串和 false 可能是合法业务值，此时应使用空值合并 `??`。`||` 适合把任何假值都视为缺省的明确场景。

可选链：

```js
const city = user.address?.city;
```

它只在链上值是 null/undefined 时停止，不会替代数据合同验证。

## 10. let、const 和 var 的作用域不同

现代代码默认使用 `const`，确实需要重新赋值时使用 `let`：

```js
const tenantId = 'tenant-A';
let total = 0;
total += 3;
```

`const` 约束变量绑定不能换成另一个值，不代表对象深度不可变：

```js
const order = { status: 'OPEN' };
order.status = 'CLOSED'; // 可以
```

`var` 是函数作用域并有特殊提升行为，新代码通常不作为默认。

## 11. 声明在使用前存在，但初始化时间不同

`let`/`const` 从代码块开始到声明前处于暂时性死区（TDZ），访问会抛错：

```js
console.log(total); // ReferenceError
const total = 3;
```

函数声明通常可在源码位置之前调用；函数表达式遵循变量初始化规则。

“全部声明都被提升所以随便用”是不准确的心智模型。写代码时按清楚的初始化顺序组织。

## 12. if/else 适合范围和组合条件

```js
if (affectedUsers < 0) {
  throw new Error('人数不能为负数');
} else if (machineStopped) {
  priority = 5;
} else if (affectedUsers >= 100) {
  priority = 4;
} else {
  priority = 2;
}
```

从上到下只执行第一个匹配分支。更具体、更紧急的规则通常放前面，防止被宽条件遮蔽。

复杂条件可拆成有业务名字的布尔值或函数，减少否定层级。

## 13. switch 适合根据一个值选择不同结果

```js
switch (status) {
  case 'OPEN':
    return '待处理';
  case 'IN_PROGRESS':
    return '处理中';
  case 'CLOSED':
    return '已关闭';
  default:
    return '未知状态';
}
```

传统 switch 若不 `break` 或 `return` 会继续落入后续 case，叫 fall-through。偶尔有意合并 case，但应写得显眼。

范围判断如 `score >= 90` 更适合 if；有限状态到结果的对应更适合 switch 或映射对象。

## 14. 三元表达式适合一个短小的二选一值

```js
const label = active ? '启用' : '停用';
```

嵌套多个三元表达式会难读。若存在多个步骤、副作用或分支解释，使用 if/else 或函数。

短不等于清楚，目标是让读者快速知道条件和两种结果。

## 15. for...of 用于遍历可迭代值

```js
for (const order of orders) {
  total += order.amountCents;
}
```

它直接给元素。经典 `for` 适合需要索引、步长或同时遍历多个位置：

```js
for (let i = 0; i < orders.length; i += 1) {
  console.log(i, orders[i]);
}
```

`for...in` 遍历对象可枚举属性名，不应作为普通数组元素循环的默认。

## 16. while 适合次数事先不确定的循环

```js
while (queue.length > 0) {
  const task = queue.shift();
  handle(task);
}
```

每个 while 都要能说明：

- 初始状态；
- 继续条件；
- 每轮怎样接近结束；
- 若一直不满足结束条件会怎样。

浏览器主线程中的无限或超长循环会冻结页面。

## 17. break、continue 和 return 结束范围不同

- `continue`：跳过当前一轮，继续循环；
- `break`：结束最近的循环或 switch；
- `return`：结束整个函数并返回值；
- `throw`：异常结束当前正常流程，沿调用栈寻找处理者。

批量统计时，即使找到第一个严重工单，仍可能要继续计算总数和总金额，因此不能 `break`。可以只在索引尚未记录时赋值：

```js
if (priority === 5 && firstCriticalIndex === -1) {
  firstCriticalIndex = i;
}
```

后面的 5 不再覆盖，但循环仍处理其他统计。

## 18. 函数把输入、处理和结果命名

```js
function calculateTotalCents(unitPriceCents, quantity) {
  return unitPriceCents * quantity;
}
```

函数合同包括：

- 参数代表什么；
- 接受哪些值；
- 返回什么；
- 可能抛什么；
- 是否修改外部状态。

名字应表达业务意图，而不是 `processData`。

## 19. 未传参数得到 undefined，多传参数通常被忽略

```js
function greet(name) {
  return `你好，${name}`;
}

greet();              // name 是 undefined
greet('A', 'extra');  // extra 未被形参接收
```

JavaScript 运行时不会按形参数量自动报错。需要边界检查或 TypeScript 帮助静态发现，但 TypeScript 也不能验证真实网络输入。

默认参数只在值是 undefined 时生效：

```js
function list(limit = 20) { ... }
```

传 null 不会使用默认值。

## 20. Rest 参数收集剩余实参

```js
function sum(...values) {
  return values.reduce((total, value) => total + value, 0);
}
```

Rest 参数必须在最后，得到真实数组。Spread 使用同样的 `...` 语法把可迭代值展开：

```js
sum(...numbers)
```

二者方向相反：rest 收集，spread 展开。

## 21. 函数声明、表达式和箭头函数

```js
function parseOrder(text) { ... }

const parseOrder2 = function (text) { ... };

const parseOrder3 = (text) => { ... };
```

箭头函数更短，并且没有自己的 `this`、`arguments` 和构造能力。对象方法需要动态 this 时，不应机械改箭头；回调只需使用外层 this 时，箭头很合适。

优先按语义选择，而不是统一追求最短。

## 22. 回调是作为值传给另一段代码的函数

```js
const critical = orders.filter(order => order.priority === 5);
```

`filter` 负责遍历和收集，回调负责判断单个元素。浏览器事件、Promise 和计时器也接收回调。

传函数与调用函数不同：

```js
button.addEventListener('click', save);   // 传函数
button.addEventListener('click', save()); // 立即调用并传返回值，通常错误
```

## 23. 纯函数更容易理解和复用

纯函数对同样输入返回同样结果，且不修改外部可观察状态：

```js
function priorityLabel(priority) {
  return priority === 5 ? '严重' : '普通';
}
```

网络、DOM、日志、随机数和当前时间属于副作用。实际应用一定需要副作用，重点是把纯规则与副作用编排分开，便于验证和复用。

## 24. JavaScript 参数传递的是值

原始值的副本：

```js
let count = 1;
function change(value) { value = 2; }
change(count);
// count 仍是 1
```

对象变量保存的是引用值，引用也按值传递：

```js
const order = { status: 'OPEN' };
function close(value) { value.status = 'CLOSED'; }
close(order);
// 同一个对象被修改
```

函数内把 `value = {}` 改指向不会改变调用者变量，但通过共同引用修改对象内容会被看到。

## 25. 词法作用域由源码嵌套位置决定

```js
const appName = 'FactoryCare';

function createLabel(id) {
  const prefix = 'WO';
  return `${appName}-${prefix}-${id}`;
}
```

函数可访问自身局部、外层和全局作用域；外层不能访问函数内部的 `prefix`。查找名称沿源码嵌套向外，不由调用函数的位置决定，这叫词法作用域。

## 26. 块作用域限制 let 和 const

```js
if (ready) {
  const message = 'ready';
}

console.log(message); // ReferenceError
```

`if`、`for` 等 `{}` 为 let/const 创建块作用域。把变量声明在最小需要范围内，可减少误用和名称冲突。

var 不遵守同样块作用域，因此旧代码里会看到不同结果。

## 27. 闭包让函数记住创建时的外层变量

```js
function createCounter() {
  let count = 0;
  return () => {
    count += 1;
    return count;
  };
}

const next = createCounter();
next(); // 1
next(); // 2
```

外层调用已经结束，返回函数仍能访问那次调用的 `count`。这就是闭包（closure）。它是模块私有状态、事件处理器和 Composable 的基础。

闭包也可能让大对象和 DOM 节点长期无法释放，所以监听器和缓存需要清理。

## 28. 循环中的闭包要看每轮绑定

```js
for (let i = 0; i < 3; i += 1) {
  handlers.push(() => i);
}
```

`let` 为每轮建立独立绑定，结果为 0、1、2。旧式 `var` 只有一个函数作用域绑定，回调执行时可能都看到最终值 3。

不要只背结论，要用“闭包捕获哪个绑定”解释。

## 29. 异常处理应保留失败边界

```js
function parseQuantity(text) {
  const value = Number(text);
  if (!Number.isInteger(value) || value < 0) {
    throw new TypeError('quantity 必须是非负整数');
  }
  return value;
}
```

`try/catch` 用在能真正恢复、转换错误合同或补充上下文的边界。不要捕获后什么都不做，也不要把编程错误全部伪装为“网络失败”。

`finally` 适合无论成功失败都要清理的资源或状态。

## 30. 这篇的整体地图

```text
值与类型
  → 显式转换和严格相等
  → 条件、switch 与循环组织流程
  → 函数命名输入、结果和副作用
  → 词法作用域决定名称查找
  → 闭包让函数保留外层状态
```

必须掌握：number 有精度与安全整数边界；空数组是真值；`??` 与 `||` 不同；`const` 不等于对象不可变；多传/少传参数不会自动按 Java 规则报错；闭包捕获绑定而不是复制一张变量截图。

位运算、生成器和特殊相等算法属于“见过即可或需要时查询”。
