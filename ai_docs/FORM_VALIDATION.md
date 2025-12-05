# Form Validation System

This project uses a comprehensive form validation system that combines server-side Ecto validations with client-side HTML5 validation and real-time visual feedback.

## How It Works

### 1. Server-Side Validation (Ecto)

Define validations in your schema changesets:

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :slug, :description, :body])
  |> validate_required([:title, :slug])
  |> validate_length(:title, min: 3, max: 255)
  |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
end
```

### 2. Automatic HTML5 Attributes

The `ValidationAttributes` module automatically extracts HTML5 validation attributes from your Ecto changeset:

**Ecto Validation** → **HTML5 Attribute**
- `validate_required/3` → `required`
- `validate_format/4` → `pattern="regex"`
- `validate_length/3` → `minlength/maxlength`
- `validate_number/3` → `min/max`
- Field types → `type` (email, number, date, etc.)

### 3. Visual Validation Hints

The system automatically displays helpful hints below inputs:

```heex
<.input field={f[:slug]} hint="Custom hint text" />
```

**Auto-generated hints:**
- Required fields: Red asterisk (*) in label
- Length constraints: "3-255 characters"
- Custom hints: For complex patterns like regex

**Example output:**
```
Title *
[input field]
3-255 characters
```

### 4. Real-Time CSS Validation States

Using CSS pseudo-classes, inputs provide instant visual feedback:

#### Invalid State (Red)
```css
input:invalid:not(:placeholder-shown):not(:focus) {
  border-color: red;
  background: light red;
}
```

**When shown:**
- Field has content (`:not(:placeholder-shown)`)
- Field fails validation (`:invalid`)
- User not currently typing (`:not(:focus)`)

#### Valid State (Green)
```css
input:valid:required:not(:placeholder-shown) {
  border-color: green;
}
```

**When shown:**
- Field has validation rules (`:required`, `[pattern]`, `[minlength]`, etc.)
- Field passes validation (`:valid`)
- Field has content (`:not(:placeholder-shown)`)

#### Focused State
When a field is focused, it shows enhanced feedback with a glow effect:
- Invalid fields: Red border + red glow
- Valid fields: Green border + green glow
- Regular fields: Blue border + blue glow

## Usage Examples

### Basic Input with Validation

```heex
<.input field={@form[:email]} type="email" label="Email" />
```

**Result:**
- Auto-detects email type
- Shows required asterisk if `validate_required`
- Turns green when valid email entered
- Turns red if invalid email entered

### Input with Pattern Validation

```heex
<.input
  field={@form[:slug]}
  label="Slug"
  hint="Lowercase letters, numbers, and hyphens only"
  placeholder="my-post-slug"
/>
```

**Result:**
- Pattern: `[a-z0-9\-]+` (auto-extracted from `validate_format`)
- Hint: Custom description
- Length: "3-255 characters" (auto-extracted)
- Required asterisk (auto-detected)
- Green border when valid, red when invalid

### Textarea with Length Constraints

```heex
<.input
  field={@form[:description]}
  type="textarea"
  label="Description"
  placeholder="A brief summary"
/>
```

**Result:**
- Shows "10-500 characters" hint
- Required asterisk
- Green when length is valid, red when too short/long

## Browser Validation Behavior

### Form Submission
When a user tries to submit a form with invalid fields:

1. Browser prevents submission
2. Focuses first invalid field
3. Shows native validation message
4. Field highlights in red (our CSS)

### Validation Messages
Browsers show native messages like:
- "Please fill out this field" (required)
- "Please match the requested format" (pattern)
- "Please lengthen this text to X characters" (minlength)

## Pattern Validation Notes

### Regex Escaping
HTML5 requires special characters to be escaped in pattern attributes:

**Ecto Regex:** `~r/^[a-z0-9-]+$/`
**HTML5 Pattern:** `[a-z0-9\-]+`

The system automatically:
1. Strips anchors (`^` and `$`) - HTML5 implies them
2. Escapes dashes (`-` → `\-`) - Required by HTML5 spec

### Custom Hints for Patterns
Since regex is hard to read, always provide a hint:

```heex
<.input
  field={@form[:username]}
  hint="4-20 characters: letters, numbers, underscore, hyphen"
/>
```

## Accessibility

The validation system is accessible:

- `<span aria-label="required">*</span>` for screen readers
- Visual indicators (color + border) for sighted users
- Native browser validation messages
- Hint text provides context before errors occur

## Dark Mode

All validation states have dark mode support:
- Invalid: Red tones adjusted for dark backgrounds
- Valid: Green tones adjusted for dark backgrounds
- Hints: Muted gray text that's readable in both modes

## Testing

Run validation tests:
```bash
mix test test/local_cafe_web/validation_attributes_test.exs
```

## Files

- **Validation extraction:** `lib/local_cafe_web/validation_attributes.ex`
- **Form component:** `lib/local_cafe_web/components/core_components.ex`
- **Styles:** `assets/css/components/forms.css`
- **Tests:** `test/local_cafe_web/validation_attributes_test.exs`
