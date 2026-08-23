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

// 自定义渲染器保存真实 Vue patch 产生的节点对象，供 key 身份严格比较。
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

export function createMemoryRoot(): MemoryNode {
  return makeNode('root', '#root')
}

export function findAll(node: MemoryNode, predicate: (candidate: MemoryNode) => boolean): MemoryNode[] {
  const result = predicate(node) ? [node] : []
  return result.concat(node.children.flatMap((child) => findAll(child, predicate)))
}

export function findByProp(root: MemoryNode, key: string, value: unknown): MemoryNode | undefined {
  return findAll(root, (node) => node.props[key] === value)[0]
}

export function nodeText(node: MemoryNode): string {
  return node.kind === 'text' ? node.text : node.children.map(nodeText).join('')
}

export function invokeClick(node: MemoryNode): void {
  const handler = node.props.onClick
  if (typeof handler !== 'function') throw new Error(`node ${node.type} has no click handler`)
  // 事件桩同时支持普通处理器和 Vue 修饰符包装器需要的方法。
  handler({ stopPropagation() {}, preventDefault() {}, target: node, currentTarget: node })
}
