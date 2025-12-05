defmodule LocalCafeWeb.ValidationAttributesPatternTest do
  use ExUnit.Case, async: true

  alias LocalCafeWeb.ValidationAttributes

  defmodule TestSchema do
    use Ecto.Schema
    import Ecto.Changeset

    schema "test" do
      field :slug, :string
    end

    def changeset(schema, attrs) do
      schema
      |> cast(attrs, [:slug])
      |> validate_required([:slug])
      |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    end
  end

  test "pattern with character class containing dash is extracted correctly" do
    changeset = TestSchema.changeset(%TestSchema{}, %{})
    attrs = ValidationAttributes.for_field(changeset, :slug)

    # Should strip anchors and escape literal dash for HTML5
    # [a-z0-9-] becomes [a-z0-9\-] per HTML5 pattern spec
    assert attrs[:pattern] == "[a-z0-9\\-]+"

    # Let's also verify the pattern would work in HTML
    pattern_value = attrs[:pattern]

    # The dash should be escaped for HTML5 pattern attribute
    assert String.contains?(pattern_value, "[a-z0-9\\-]")
  end

  test "extracted pattern matches valid slugs" do
    changeset = TestSchema.changeset(%TestSchema{}, %{})
    attrs = ValidationAttributes.for_field(changeset, :slug)
    pattern = attrs[:pattern]

    # Create a JavaScript-compatible regex to test
    # (HTML pattern uses JavaScript regex syntax)
    js_regex = ~r/^#{pattern}$/

    # Valid slugs
    assert "hello" =~ js_regex
    assert "hello-world" =~ js_regex
    assert "test-123" =~ js_regex
    assert "abc123xyz" =~ js_regex

    # Invalid slugs (should NOT match)
    refute "asdf$" =~ js_regex
    refute "HELLO" =~ js_regex
    refute "hello_world" =~ js_regex
    refute "hello world" =~ js_regex
  end
end
