// 这些固定值构成教学矩阵的数据源，不读取网络、环境变量或真实工单。
const numberValue = 42;
const stringValue = "42";
const booleanValue = false;
const nullValue = null;
const undefinedValue = undefined;
const nanValue = Number("not-a-number");

// 每行同时输出值与类型；NaN 使用专用探针，避免错误地与自身比较。
console.log(`number=${numberValue},type=${typeof numberValue}`);
console.log(`string=${stringValue},type=${typeof stringValue}`);
console.log(`boolean=${booleanValue},type=${typeof booleanValue}`);
console.log(`null=${nullValue},type=${typeof nullValue}`);
console.log(`undefined=${undefinedValue},type=${typeof undefinedValue}`);
console.log(`nan=${nanValue},type=${typeof nanValue},isNaN=${Number.isNaN(nanValue)}`);

// 下面三行固定显式转换、严格相等和保留合法零值的预言。
console.log(`converted=${Number(stringValue)},type=${typeof Number(stringValue)}`);
console.log(`strictTextVsNumber=${stringValue === numberValue}`);
console.log(`nullishZero=${0 ?? 30}`);

// 两个独立对象身份不等；别名仍与原对象严格相等。
const firstSnapshot = { status: "CREATED" };
const secondSnapshot = { status: "CREATED" };
const aliasSnapshot = firstSnapshot;
console.log(`separateObjects=${firstSnapshot === secondSnapshot}`);
console.log(`sameReference=${firstSnapshot === aliasSnapshot}`);
