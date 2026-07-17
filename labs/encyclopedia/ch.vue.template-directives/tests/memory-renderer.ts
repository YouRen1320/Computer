import { createRenderer } from 'vue'

export interface MemoryNode {
  kind: 'root' | 'element' | 'text' | 'comment'
  type: string
  text: string
  props: Record<string, unknown>
  style: Record<string, string>
  children: MemoryNode[]
  parent: MemoryNode | null
}

function makeNode(kind: MemoryNode['kind'], type: string, text = ''): MemoryNode {
  return { kind, type, text, props: {}, style: {}, children: [], parent: null }
}

function detach(node: MemoryNode): void {
  if (!node.parent) return
  const index = node.parent.children.indexOf(node)
  if (index >= 0) node.parent.children.splice(index, 1)
  node.parent = null
}

// 内存节点保留对象身份与绑定属性，让测试直接观察 Vue patch 的复用决策。
export const memoryRenderer = createRenderer<MemoryNode, MemoryNode>({
  patchProp(element, key, _previous, next) {
    if (key === 'style' && next && typeof next === 'object') Object.assign(element.style, next)
    else if (next == null) delete element.props[key]
    else element.props[key] = next
  },
  insert(child, parent, anchor = null) {
    detach(child)
    child.parent = parent
    const index = anchor ? parent.children.indexOf(anchor) : -1
    if (index >= 0) parent.children.splice(index, 0, child)
    else parent.children.push(child)
  },
  remove: detach,
  createElement(type) { return makeNode('element', type) },
  createText(text) { return makeNode('text', '#text', text) },
  createComment(text) { return makeNode('comment', '#comment', text) },
  setText(node, text) { node.text = text },
  setElementText(element, text) {
    element.children.forEach((child) => { child.parent = null })
    element.children = []
    if (text) {
      const child = makeNode('text', '#text', text)
      child.parent = element
      element.children.push(child)
    }
  },
  parentNode(node) { return node.parent },
  nextSibling(node) {
    if (!node.parent) return null
    const index = node.parent.children.indexOf(node)
    return node.parent.children[index + 1] ?? null
  },
  setScopeId(element, id) { element.props[id] = '' },
})

export function createMemoryRoot(): MemoryNode { return makeNode('root', '#root') }

export function findAll(node: MemoryNode, predicate: (candidate: MemoryNode) => boolean): MemoryNode[] {
  const own = predicate(node) ? [node] : []
  return own.concat(node.children.flatMap((child) => findAll(child, predicate)))
}

export function findByProp(root: MemoryNode, key: string, value: unknown): MemoryNode | undefined {
  return findAll(root, (node) => node.props[key] === value)[0]
}

export function nodeText(node: MemoryNode): string {
  return node.kind === 'text' ? node.text : node.children.map(nodeText).join('')
}

export function invokeClick(node: MemoryNode): { stopped: boolean; prevented: boolean } {
  const handler = node.props.onClick
  if (typeof handler !== 'function') throw new Error(`node ${node.type} has no click handler`)
  const result = { stopped: false, prevented: false }
  // 修饰符包装器通过这两个方法留下可断言的传播/默认行为证据。
  handler({
    stopPropagation() { result.stopped = true },
    preventDefault() { result.prevented = true },
    target: node,
    currentTarget: node,
  })
  return result
}
