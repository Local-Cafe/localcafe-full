defmodule LocalCafeWeb.ValidationAttributes do
  @moduledoc """
  Extracts HTML5 validation attributes from Ecto changeset validations.

  Inspects the changeset's validations list and converts them into HTML5
  input attributes for client-side validation.

  ## Examples

      changeset = User.changeset(%User{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :email)
      # => %{required: true, type: "email", maxlength: 160}

  ## Supported Validations

  - `validate_required/3` → `required: true`
  - `validate_format/4` → `pattern: "regex"` (strips leading `^` and trailing `$` anchors since HTML5 pattern matching is full-string by default; escapes literal dashes in character classes per HTML5 spec)
  - `validate_length/3`:
    - `:min` → `minlength: n`
    - `:max` → `maxlength: n`
    - `:is` → `minlength: n, maxlength: n`
  - `validate_number/3`:
    - `:greater_than` → `min: n + step`
    - `:greater_than_or_equal_to` → `min: n`
    - `:less_than` → `max: n - step`
    - `:less_than_or_equal_to` → `max: n`
  - Field types:
    - `:integer`, `:float`, `:decimal` → `type: "number"`
    - `:date` → `type: "date"`
    - `:time` → `type: "time"`
    - `:utc_datetime`, `:naive_datetime` → `type: "datetime-local"`
  """

  @doc """
  Returns HTML5 validation attributes for a specific field in a changeset.

  ## Parameters

  - `changeset` - An Ecto.Changeset struct
  - `field` - The field name as an atom

  ## Returns

  A map of HTML attributes suitable for use in form inputs.

  ## Examples

      iex> changeset = Post.changeset(%Post{}, %{})
      iex> ValidationAttributes.for_field(changeset, :title)
      %{required: true, maxlength: 255}
  """
  def for_field(%Ecto.Changeset{} = changeset, field) when is_atom(field) do
    attrs = %{}

    # Get field type from schema
    attrs = put_type_attribute(attrs, changeset, field)

    # Check if field is required (stored separately from validations)
    attrs = if field in changeset.required, do: Map.put(attrs, :required, true), else: attrs

    # Extract validation rules
    attrs = extract_validations(attrs, changeset, field)

    attrs
  end

  # Determine input type based on Ecto schema field type
  defp put_type_attribute(attrs, changeset, field) do
    case get_field_type(changeset, field) do
      type when type in [:integer, :float, :decimal] ->
        Map.put(attrs, :type, "number")

      :date ->
        Map.put(attrs, :type, "date")

      :time ->
        Map.put(attrs, :type, "time")

      type when type in [:utc_datetime, :naive_datetime] ->
        Map.put(attrs, :type, "datetime-local")

      :boolean ->
        Map.put(attrs, :type, "checkbox")

      _ ->
        attrs
    end
  end

  # Get the Ecto type for a field from the schema
  defp get_field_type(%{data: %schema{}}, field) do
    if function_exported?(schema, :__schema__, 2) do
      schema.__schema__(:type, field)
    else
      nil
    end
  end

  defp get_field_type(_, _), do: nil

  # Extract validations by traversing the changeset
  defp extract_validations(attrs, changeset, field) do
    changeset.validations
    |> Enum.reduce(attrs, fn
      # validate_format
      {^field, {:format, %Regex{source: pattern}}}, acc ->
        # Strip leading ^ and trailing $ since HTML5 pattern matching is full-string by default
        # The browser implicitly adds ^(?: and )$ around the pattern
        cleaned_pattern =
          pattern
          |> String.replace(~r/^\^/, "")
          |> String.replace(~r/\$$/, "")
          |> escape_pattern_for_html5()

        Map.put(acc, :pattern, cleaned_pattern)

      # validate_length
      {^field, {:length, opts}}, acc ->
        acc = if min = Keyword.get(opts, :min), do: Map.put(acc, :minlength, min), else: acc
        acc = if max = Keyword.get(opts, :max), do: Map.put(acc, :maxlength, max), else: acc

        acc =
          if is = Keyword.get(opts, :is) do
            acc
            |> Map.put(:minlength, is)
            |> Map.put(:maxlength, is)
          else
            acc
          end

        acc

      # validate_number
      {^field, {:number, opts}}, acc ->
        acc =
          if greater_than = Keyword.get(opts, :greater_than) do
            step = get_step(acc)
            Map.put(acc, :min, greater_than + step)
          else
            acc
          end

        acc =
          if gte = Keyword.get(opts, :greater_than_or_equal_to) do
            Map.put(acc, :min, gte)
          else
            acc
          end

        acc =
          if less_than = Keyword.get(opts, :less_than) do
            step = get_step(acc)
            Map.put(acc, :max, less_than - step)
          else
            acc
          end

        acc =
          if lte = Keyword.get(opts, :less_than_or_equal_to) do
            Map.put(acc, :max, lte)
          else
            acc
          end

        acc

      # validate_acceptance
      {^field, {:acceptance, _opts}}, acc ->
        acc
        |> Map.put(:required, true)
        |> Map.put(:type, "checkbox")

      # Other validations for this field (no HTML5 equivalent)
      {^field, _validation}, acc ->
        acc

      # Validations for other fields
      _, acc ->
        acc
    end)
  end

  # Get step value for number inputs (default to 1 for integers, 0.01 for floats)
  defp get_step(attrs) do
    case Map.get(attrs, :type) do
      "number" -> Map.get(attrs, :step, 1)
      _ -> 1
    end
  end

  # Escape special characters for HTML5 pattern attribute
  # According to MDN, these characters must be escaped: ( ) [ { } / - |
  # For character classes, we need to escape literal dashes
  defp escape_pattern_for_html5(pattern) do
    # Escape literal dashes in character classes (at the end or beginning)
    # [a-z0-9-] becomes [a-z0-9\-]
    pattern
    # Escape dash at end of character class
    |> String.replace(~r/(?<!\\)-\]/, "\\-]")
    # Escape dash at start of character class
    |> String.replace(~r/\[(?<!\\)-/, "[\\-")
  end

  @doc """
  Returns HTML5 validation attributes as a keyword list suitable for Phoenix.Component attr.

  This is a convenience function that converts the map from `for_field/2` into
  a keyword list that can be easily merged with other HTML attributes.

  ## Examples

      iex> changeset = Post.changeset(%Post{}, %{})
      iex> ValidationAttributes.to_attrs(changeset, :title)
      [required: true, maxlength: 255]
  """
  def to_attrs(changeset, field) do
    changeset
    |> for_field(field)
    |> Map.to_list()
  end

  @doc """
  Merges validation attributes with existing attributes, with existing attributes taking precedence.

  ## Examples

      iex> existing = %{class: "input", required: false}
      iex> validations = %{required: true, maxlength: 100}
      iex> ValidationAttributes.merge_attrs(existing, validations)
      %{class: "input", required: false, maxlength: 100}
  """
  def merge_attrs(existing, validation_attrs)
      when is_map(existing) and is_map(validation_attrs) do
    Map.merge(validation_attrs, existing)
  end

  def merge_attrs(existing, validation_attrs)
      when is_list(existing) and is_map(validation_attrs) do
    existing_map = Map.new(existing)

    validation_attrs
    |> Map.merge(existing_map)
    |> Map.to_list()
  end

  def merge_attrs(existing, validation_attrs)
      when is_map(existing) and is_list(validation_attrs) do
    validation_map = Map.new(validation_attrs)
    Map.merge(validation_map, existing)
  end

  def merge_attrs(existing, validation_attrs)
      when is_list(existing) and is_list(validation_attrs) do
    existing_map = Map.new(existing)
    validation_map = Map.new(validation_attrs)

    validation_map
    |> Map.merge(existing_map)
    |> Map.to_list()
  end
end
