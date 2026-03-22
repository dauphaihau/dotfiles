Create a new React component named $ARGUMENTS.

## Structure rules

**If the component has sub-components → use folder + barrel pattern:**
```
ComponentName/
  ├── index.ts           ← export { default } from './ComponentName'
  ├── ComponentName.tsx  ← root logic
  ├── SubComponentA.tsx
  └── SubComponentB.tsx
```

**If the component is standalone (no sub-components) → single file:**
```
ComponentName.tsx   ← no folder needed
```

## Rules
- Never create a folder for a single-file component
- Never name root logic file `index.tsx`
- `index.ts` is re-export only, no JSX or logic
- Sub-folders follow the same pattern recursively