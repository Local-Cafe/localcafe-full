# Color System Reference

## Philosophy

The color system uses **semantic color variables** that automatically adapt to light/dark modes. Component stylesheets never use literal colors or mode-specific selectors - they only use semantic variables.

## How It Works

### 1. Literal Colors (tokens/colors.css)
Literal color palette prefixed with `--literal-*` - **never use these directly in components**:
- `--literal-black`, `--literal-white`
- `--literal-gold`, `--literal-gold-light`, `--literal-gold-dark`, `--literal-gold-darkest`
- `--literal-gray-100` through `--literal-gray-800`
- `--literal-cream-100`, `--literal-cream-200`, `--literal-cream-300`
- `--literal-error`, `--literal-success`, `--literal-warning`

### 2. Semantic Colors (tokens/colors.css)
Use these in your components - they automatically change based on light/dark mode:

#### Background Colors
- `--color-background` - Primary page background
- `--color-background-secondary` - Cards, code blocks, alternate sections
- `--color-background-tertiary` - Even more subtle backgrounds

#### Foreground/Text Colors
- `--color-foreground` - Primary text color
- `--color-foreground-secondary` - Secondary text, less emphasis
- `--color-foreground-tertiary` - Tertiary text, least emphasis
- `--color-foreground-inverse` - Text on colored backgrounds

#### Primary Brand Colors
- `--color-primary` - Main brand color (gold in various shades)
- `--color-primary-hover` - Hover state for primary color
- `--color-primary-contrast` - Text color on primary background

#### Border Colors
- `--color-border` - Standard borders
- `--color-border-subtle` - Very subtle borders
- `--color-border-strong` - Emphasized borders

#### State Colors
- `--color-error` / `--color-error-background`
- `--color-success` / `--color-success-background`
- `--color-warning` / `--color-warning-background`

## Usage Pattern

### ✅ CORRECT - Use semantic colors in components

```css
@layer components {
  .my-component {
    background-color: var(--color-background);
    color: var(--color-foreground);
    border: var(--border-width) solid var(--color-border);
  }

  .my-component-header {
    background-color: var(--color-background-secondary);
    color: var(--color-foreground-secondary);
  }

  .my-button {
    background-color: var(--color-primary);
    color: var(--color-primary-contrast);
  }

  .my-button:hover {
    background-color: var(--color-primary-hover);
  }
}
```

### ❌ INCORRECT - Don't use literal colors or mode selectors in components

```css
/* DON'T DO THIS */
@layer components {
  .my-component {
    background-color: var(--literal-cream-100); /* ❌ Use --color-background instead */
    color: var(--literal-gray-800); /* ❌ Use --color-foreground instead */
  }

  /* ❌ Don't add mode-specific rules in components */
  @media (prefers-color-scheme: dark) {
    .my-component {
      background-color: var(--literal-black);
    }
  }
}
```

## Mode Behavior

The semantic colors are defined for all three modes:

1. **System Light** (default `:root`)
   - Cream backgrounds with dark text
   - Darker gold for contrast

2. **System Dark** (`@media (prefers-color-scheme: dark)`)
   - Black backgrounds with gold text
   - Brighter gold for contrast

3. **Forced Light** (`:root[data-theme="light"]`)
   - Same as system light, overrides dark system preference

4. **Forced Dark** (`:root[data-theme="dark"]`)
   - Same as system dark, overrides light system preference

## Migration Guide

When adding background colors back to components:

1. **Read the component CSS file**
2. **Add only background colors** using semantic variables:
   - `background-color: var(--color-background);`
   - `background-color: var(--color-background-secondary);`
   - `background-color: var(--color-background-tertiary);`
3. **Do NOT add text colors, borders, or other colors yet** - focus on backgrounds first
4. **Do NOT add any mode-specific selectors** - semantic colors handle this automatically

## Example: base/elements.css

```css
@layer base {
  body {
    font-family: var(--font-base);
    background-color: var(--color-background);  /* ✅ Semantic */
    color: var(--color-foreground);             /* ✅ Semantic */
  }

  code {
    padding: var(--space-1) var(--space-2);
    background-color: var(--color-background-secondary); /* ✅ */
  }

  a {
    color: var(--color-primary);       /* ✅ */
  }

  a:hover {
    color: var(--color-primary-hover); /* ✅ */
  }
}
```

## Benefits

1. **No duplication** - Define colors once in tokens, use everywhere
2. **No mode selectors in components** - Clean, simple component code
3. **Easy theming** - Change one token file to update entire site
4. **Type safety** - Clear naming makes it obvious what each color is for
5. **Maintainable** - Adding new colors or modes doesn't require touching components
