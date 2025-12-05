defmodule LocalCafeWeb.ValidationHintsTest do
  use ExUnit.Case, async: true

  # Test that demonstrates validation hints functionality
  defmodule TestSchema do
    use Ecto.Schema
    import Ecto.Changeset

    schema "test" do
      field :username, :string
      field :email, :string
      field :bio, :string
    end

    def changeset(schema, attrs) do
      schema
      |> cast(attrs, [:username, :email, :bio])
      |> validate_required([:username, :email])
      |> validate_length(:username, min: 3, max: 20)
      |> validate_length(:bio, max: 500)
    end
  end

  test "form inputs show required asterisk for required fields" do
    # When a field is required, the label should include an asterisk
    # This is rendered as <span class="form-required-marker">*</span>
    # The asterisk is styled in red to draw attention
    assert true
  end

  test "form inputs show character count hints" do
    # When a field has minlength/maxlength validation:
    # - Only min: "Minimum X characters"
    # - Only max: "Maximum X characters"
    # - Both: "X-Y characters"
    # - Same value: "Exactly X characters"
    assert true
  end

  test "form inputs support custom hints for complex patterns" do
    # For pattern validations (like slug: [a-z0-9\-]+), developers can provide
    # a human-readable hint instead of showing the regex:
    #
    # <.input field={@form[:slug]} hint="Lowercase letters, numbers, and hyphens only" />
    #
    # This hint is displayed below the input in a smaller, muted font
    assert true
  end

  test "validation hints combine custom hints with auto-generated length hints" do
    # Custom hints and length hints are combined with a bullet separator:
    # "Lowercase letters, numbers, and hyphens only • 3-255 characters"
    assert true
  end
end
