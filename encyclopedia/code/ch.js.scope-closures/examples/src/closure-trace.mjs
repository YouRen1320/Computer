// 工厂把 count 声明在每次调用环境中，返回方法只访问各自实例状态。
function createCounter(name) {
  let count = 0;

  function increment() {
    count += 1;
    return `${name}:${count}`;
  }

  function read() {
    return count;
  }

  return { increment, read };
}

const first = createCounter("first");
const second = createCounter("second");

// 交叉调用输出证明 first 与 second 的 count 绑定相互隔离。
console.log(first.increment());
console.log(first.increment());
console.log(second.increment());
console.log(`firstRead=${first.read()}`);
console.log(`secondRead=${second.read()}`);

const source = "module";
function readSource() {
  // 自由变量按函数定义位置解析到模块 source，而不是调用者局部绑定。
  return source;
}

function callReader() {
  const source = "caller";
  void source;
  return readSource();
}

console.log(`lexical=${callReader()}`);

// 状态视图同时暴露当前绑定读取和创建时快照读取，二者语义有意不同。
function createStatusView() {
  let currentStatus = "CREATED";
  const snapshotStatus = currentStatus;

  return {
    update(nextStatus) {
      currentStatus = nextStatus;
    },
    readCurrent() {
      return currentStatus;
    },
    readSnapshot() {
      return snapshotStatus;
    },
  };
}

const view = createStatusView();
view.update("ASSIGNED");
console.log(`current=${view.readCurrent()}`);
console.log(`snapshot=${view.readSnapshot()}`);
