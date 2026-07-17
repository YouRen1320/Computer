import { readFile } from 'node:fs/promises'

// Responsibility: check submitted source affordances that happy-dom cannot visually or auditorily verify.
const dialog = await readFile(new URL('../src/AccessibleWorkOrderDialog.vue', import.meta.url), 'utf8')
const route = await readFile(new URL('../src/RouteFocusRegion.vue', import.meta.url), 'utf8')
const app = await readFile(new URL('../src/App.vue', import.meta.url), 'utf8')
for (const token of ['<Teleport to="body">', 'role="dialog"', 'aria-modal="true"', 'aria-labelledby=', 'role="alert"', 'role="status"', 'aria-live="polite"', "event.key === 'Escape'", 'await nextTick()', 'returnTarget.value?.focus()']) {
  if (!dialog.includes(token)) throw new Error(`dialog contract missing: ${token}`)
}
for (const token of ['await nextTick()', 'tabindex="-1"', 'headingElement.value?.focus()']) {
  if (!route.includes(token)) throw new Error(`route focus contract missing: ${token}`)
}
for (const token of [':focus-visible', 'prefers-reduced-motion', 'skip-link', 'min-height: 44px']) {
  if (!app.includes(token)) throw new Error(`perceivable/keyboard style affordance missing: ${token}`)
}
console.log('PASS static-a11y semantics=present focus=sequenced feedback=textual visual-at=UNVERIFIED')
