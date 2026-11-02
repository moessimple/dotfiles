# Visual review and evidence

Read this only when the change alters something a user sees or touches (UI, layout, interaction, motion). It holds the parts of Step 3 and Step 4 that apply to such a change.

## Visual verdict (Step 3)

A code review does not establish that the result looks and behaves right, so a second read-only reviewer, separate from the code review, inspects the evidence itself: the before and after captures, the device results, and a running preview when one is available. It returns **PASS** or **FAIL** with the reason for each finding, checking for clipping, overflow, error or missing states, layout shift, and whether the captures show what the description will claim. Missing captures or device results for a changed state are a **FAIL**, not a pass with a gap.

## With media template (Step 4)

The same as the text only template, plus this section between Validation and Independent review, and the Validation note on mobile interactions moves into its Device verification subsection:

```markdown
## Visual evidence

{Before and after screenshots against the base branch with comparable, realistic data, and a recording where behavior, loading, or motion matters. Cover each changed UI in the states the change touches (success, failure, focus, loading, empty or long content). Label each with the UI, state, viewport, theme, and environment it shows, and mark simulated failures and emulation as such. State the observed behavior and, where layout can move, the layout-shift result. Only files that exist locally, referenced as `![label](./path.png)` and uploaded with `--attach` in Step 6. A missing shot is listed by name here and under Limitations; never write an image link without a file behind it.}

### Device verification

{Device, operating system, and browser, and whether hardware, simulator, or emulation. Viewport emulation alone does not verify the on-screen keyboard, browser controls, safe areas, or touch. For each changed mobile interaction, the observed result for: inputs and primary actions with the keyboard open, fixed controls clear of navigation and browser controls, safe areas, touch, scrolling past the first screen, client-side navigation, and a fresh reload. Or one sentence on why no changed mobile interaction applies.}
```

The Independent review section also carries the visual verdict from Step 3 with its reviewed captures, stated separately from the code verdict, since a code review does not establish visual correctness.
