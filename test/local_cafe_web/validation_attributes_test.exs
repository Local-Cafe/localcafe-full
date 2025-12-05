defmodule LocalCafeWeb.ValidationAttributesTest do
  use ExUnit.Case, async: true

  alias LocalCafeWeb.ValidationAttributes

  # Test schema for validations
  defmodule TestPost do
    use Ecto.Schema
    import Ecto.Changeset

    schema "posts" do
      field :title, :string
      field :slug, :string
      field :description, :string
      field :body, :string
      field :published_at, :date
      field :views, :integer
      field :rating, :float
      field :price, :decimal
      field :draft, :boolean
      field :published_time, :time
      field :published_datetime, :utc_datetime
    end

    def changeset(post, attrs) do
      post
      |> cast(attrs, [
        :title,
        :slug,
        :description,
        :body,
        :published_at,
        :views,
        :rating,
        :price,
        :draft,
        :published_time,
        :published_datetime
      ])
      |> validate_required([:title, :slug])
      |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
      |> validate_format(:description, ~r/[a-z]+/)
      |> validate_length(:title, min: 3, max: 255)
      |> validate_length(:description, max: 500)
      |> validate_length(:body, is: 100)
      |> validate_number(:views, greater_than: 0)
      |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
      |> validate_number(:price, greater_than: 0, less_than: 1000)
    end

    def minimal_changeset(post, attrs) do
      post
      |> cast(attrs, [:title])
      |> validate_required([:title])
    end
  end

  describe "for_field/2 with validate_required" do
    test "returns required: true for required fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :title)

      assert attrs[:required] == true
    end

    test "does not return required for non-required fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :body)

      refute Map.has_key?(attrs, :required)
    end
  end

  describe "for_field/2 with validate_format" do
    test "returns pattern attribute with regex (anchors stripped, dash escaped)" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :slug)

      # Anchors ^ and $ are stripped since HTML5 pattern matching is full-string by default
      # Literal dashes in character classes are escaped per HTML5 spec
      assert attrs[:pattern] == "[a-z0-9\\-]+"
    end

    test "includes both required and pattern" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :slug)

      assert attrs[:required] == true
      assert attrs[:pattern] == "[a-z0-9\\-]+"
    end

    test "preserves patterns without anchors" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :description)

      # Pattern without anchors should be preserved as-is
      assert attrs[:pattern] == "[a-z]+"
    end
  end

  describe "for_field/2 with validate_length" do
    test "returns minlength and maxlength for min/max constraints" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :title)

      assert attrs[:minlength] == 3
      assert attrs[:maxlength] == 255
    end

    test "returns only maxlength when only max is specified" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :description)

      assert attrs[:maxlength] == 500
      refute Map.has_key?(attrs, :minlength)
    end

    test "returns both minlength and maxlength for is: constraint" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :body)

      assert attrs[:minlength] == 100
      assert attrs[:maxlength] == 100
    end
  end

  describe "for_field/2 with validate_number" do
    test "returns min for greater_than constraint" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :views)

      # greater_than: 0 means min should be 1 (0 + step of 1)
      assert attrs[:min] == 1
    end

    test "returns min for greater_than_or_equal_to constraint" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :rating)

      assert attrs[:min] == 1
      assert attrs[:max] == 5
    end

    test "handles greater_than with less_than" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :price)

      # greater_than: 0 means min: 1, less_than: 1000 means max: 999
      assert attrs[:min] == 1
      assert attrs[:max] == 999
    end
  end

  describe "for_field/2 with field types" do
    test "returns type: number for integer fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :views)

      assert attrs[:type] == "number"
    end

    test "returns type: number for float fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :rating)

      assert attrs[:type] == "number"
    end

    test "returns type: number for decimal fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :price)

      assert attrs[:type] == "number"
    end

    test "returns type: date for date fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :published_at)

      assert attrs[:type] == "date"
    end

    test "returns type: time for time fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :published_time)

      assert attrs[:type] == "time"
    end

    test "returns type: datetime-local for datetime fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :published_datetime)

      assert attrs[:type] == "datetime-local"
    end

    test "returns type: checkbox for boolean fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :draft)

      assert attrs[:type] == "checkbox"
    end

    test "does not return type for string fields" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :title)

      refute Map.has_key?(attrs, :type)
    end
  end

  describe "for_field/2 with non-existent field" do
    test "returns empty map for field not in schema" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :nonexistent)

      assert attrs == %{}
    end
  end

  describe "for_field/2 with minimal validations" do
    test "returns only required for simple changeset" do
      changeset = TestPost.minimal_changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :title)

      assert attrs == %{required: true}
    end
  end

  describe "to_attrs/2" do
    test "converts map to keyword list" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.to_attrs(changeset, :title)

      assert is_list(attrs)
      assert attrs[:required] == true
      assert attrs[:minlength] == 3
      assert attrs[:maxlength] == 255
    end
  end

  describe "merge_attrs/2 with maps" do
    test "merges validation attrs with existing attrs, existing takes precedence" do
      existing = %{class: "input", required: false, maxlength: 100}
      validation = %{required: true, minlength: 5, maxlength: 200}

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert result[:class] == "input"
      assert result[:required] == false
      assert result[:minlength] == 5
      assert result[:maxlength] == 100
    end

    test "adds validation attrs when not in existing" do
      existing = %{class: "input"}
      validation = %{required: true, maxlength: 100}

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert result[:class] == "input"
      assert result[:required] == true
      assert result[:maxlength] == 100
    end

    test "works with empty existing attrs" do
      existing = %{}
      validation = %{required: true, maxlength: 100}

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert result[:required] == true
      assert result[:maxlength] == 100
    end
  end

  describe "merge_attrs/2 with lists" do
    test "merges keyword lists, existing takes precedence" do
      existing = [class: "input", required: false]
      validation = [required: true, minlength: 5]

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert is_list(result)
      assert result[:class] == "input"
      assert result[:required] == false
      assert result[:minlength] == 5
    end

    test "converts between maps and lists" do
      existing = [class: "input"]
      validation = %{required: true}

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert is_list(result)
      assert result[:class] == "input"
      assert result[:required] == true
    end
  end

  describe "merge_attrs/2 edge cases" do
    test "handles empty validation attrs" do
      existing = %{class: "input"}
      validation = %{}

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert result[:class] == "input"
    end

    test "handles nil values" do
      existing = %{required: nil}
      validation = %{required: true}

      result = ValidationAttributes.merge_attrs(existing, validation)

      assert result[:required] == nil
    end
  end

  describe "integration with combined validations" do
    test "combines multiple validation types correctly" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :title)

      # Should have required, minlength, and maxlength
      assert attrs[:required] == true
      assert attrs[:minlength] == 3
      assert attrs[:maxlength] == 255
      # Should not have type since it's a string field
      refute Map.has_key?(attrs, :type)
    end

    test "combines type with validations" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :views)

      # Should have type: number and min from validations
      assert attrs[:type] == "number"
      assert attrs[:min] == 1
    end

    test "combines type, required, and range for rating" do
      changeset = TestPost.changeset(%TestPost{}, %{})
      attrs = ValidationAttributes.for_field(changeset, :rating)

      assert attrs[:type] == "number"
      assert attrs[:min] == 1
      assert attrs[:max] == 5
    end
  end
end
