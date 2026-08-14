---
paths:
  - "**/*.php"
---

## Docblocks

Do not write a docblock that repeats what the signature already states: native parameter types, property types,
return types, the method name, or obvious behavior. Write one only for what the signature cannot carry:

- generics and array shapes (`@return Collection<int, User>`, `@param array{id: int, name: string}`)
- annotations a static analyser or the framework actually requires
- a public API contract a caller cannot infer: preconditions, thrown exceptions, side effects, usage limits

When a docblock is needed for one parameter or return type, add the rest as well, so the block is not half typed.
