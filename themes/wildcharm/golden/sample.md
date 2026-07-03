# Golden sample — markdown

Prose with **bold**, *italic*, a `code span`, and a
[link to the roadmap](../../../docs/theme-roadmap.md).

## A list and a quote

- strings render `bright_green`
- keywords render `bright_blue`

> Never invent a shade — add it to `palette.yml` first.

```python
def contrast(fg: str, bg: str) -> float:
    """WCAG relative-luminance ratio."""  # see docs/theme-roadmap.md
    hi, lo = sorted((lum(fg), lum(bg)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)
```
