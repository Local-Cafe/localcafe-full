defmodule LocalCafeWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  Components are styled with vanilla CSS and semantic class names. Component
  styles are located in `assets/css/components/`.

  Useful references:

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

    * [MDN Web Docs](https://developer.mozilla.org/) - comprehensive web
      platform documentation for HTML, CSS, and JavaScript.

  """
  use Phoenix.Component
  use Gettext, backend: LocalCafeWeb.Gettext

  alias LocalCafeWeb.ValidationAttributes

  # Delegate web components from separate modules
  defdelegate flash(assigns), to: LocalCafeWeb.FlashComponent

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary secondary danger)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary ",
      "secondary" => "btn-secondary",
      "danger" => "btn-danger",
      nil => "btn-secondary"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        ["button", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :hint, :string,
    default: nil,
    doc: "helper text to display below the input describing validation requirements"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    # Extract validation attributes from the changeset
    validation_attrs = extract_validation_attrs(field)

    # Merge validation attributes with existing :rest, with :rest taking precedence
    rest = Map.get(assigns, :rest, %{})
    merged_rest = ValidationAttributes.merge_attrs(validation_attrs, rest)

    # Convert to keyword list and normalize boolean attributes
    merged_rest = normalize_rest_attrs(merged_rest)

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> assign(:rest, merged_rest)
    |> assign_new(:validation_hint, fn ->
      generate_validation_hint(merged_rest, assigns[:hint])
    end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="form-field">
      <label class="checkbox-label">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "form-checkbox"}
          {@rest}
        />
        <span class="checkbox-label-text">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="form-field">
      <label>
        <span :if={@label} class="form-label">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "form-select", @errors != [] && (@error_class || "form-input-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns =
      assign_new(assigns, :validation_hint, fn ->
        generate_validation_hint(assigns[:rest] || %{}, assigns[:hint])
      end)

    ~H"""
    <div class="form-field">
      <label>
        <span :if={@label} class="form-label">
          {@label}
          <span :if={is_required?(@rest)} class="form-required-marker" aria-label="required">*</span>
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "form-textarea",
            @errors != [] && (@error_class || "form-input-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.input_hint :if={@validation_hint} hint={@validation_hint} />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns =
      assign_new(assigns, :validation_hint, fn ->
        generate_validation_hint(assigns[:rest] || %{}, assigns[:hint])
      end)

    ~H"""
    <div class="form-field">
      <label>
        <span :if={@label} class="form-label">
          {@label}
          <span :if={is_required?(@rest)} class="form-required-marker" aria-label="required">*</span>
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "form-input",
            @errors != [] && (@error_class || "form-input-error")
          ]}
          {@rest}
        />
      </label>
      <.input_hint :if={@validation_hint} hint={@validation_hint} />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Normalize rest attributes to ensure boolean attributes render correctly
  defp normalize_rest_attrs(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn
      # Remove boolean attributes that are false
      {key, false} when key in [:required, :disabled, :readonly, :multiple] -> nil
      # Keep boolean attributes that are true
      {key, true} when key in [:required, :disabled, :readonly, :multiple] -> {key, true}
      # Keep all other attributes as-is
      {key, value} -> {key, value}
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_rest_attrs(attrs) when is_list(attrs) do
    attrs
    |> Enum.map(fn
      {key, false} when key in [:required, :disabled, :readonly, :multiple] -> nil
      {key, true} when key in [:required, :disabled, :readonly, :multiple] -> {key, true}
      {key, value} -> {key, value}
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Extract validation attributes from a form field's changeset
  defp extract_validation_attrs(%Phoenix.HTML.FormField{form: form, field: field_name}) do
    # Always extract validation attributes for client-side validation
    extract_from_changeset(form.source, field_name)
  end

  # Extract from changeset if available
  defp extract_from_changeset(%Ecto.Changeset{} = changeset, field_name) do
    ValidationAttributes.for_field(changeset, field_name)
  end

  defp extract_from_changeset(_, _), do: %{}

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="form-error">
      <span aria-hidden="true">⚠</span>
      {render_slot(@inner_block)}
    </p>
    """
  end

  # Helper used by inputs to display validation hints
  defp input_hint(assigns) do
    ~H"""
    <p class="form-hint">{@hint}</p>
    """
  end

  # Check if a field is required based on rest attributes
  defp is_required?(rest) when is_list(rest), do: Keyword.get(rest, :required, false) == true
  defp is_required?(rest) when is_map(rest), do: Map.get(rest, :required, false) == true
  defp is_required?(_), do: false

  # Generate validation hint text from validation attributes
  defp generate_validation_hint(rest, custom_hint) when is_list(rest) do
    generate_validation_hint(Map.new(rest), custom_hint)
  end

  defp generate_validation_hint(rest, custom_hint) when is_map(rest) do
    hints = []

    # Add custom hint if provided (useful for pattern explanations)
    hints = if custom_hint, do: [custom_hint | hints], else: hints

    # Add length constraints
    minlength = Map.get(rest, :minlength)
    maxlength = Map.get(rest, :maxlength)

    hints =
      case {minlength, maxlength} do
        {nil, nil} -> hints
        {min, nil} -> ["Minimum #{min} characters" | hints]
        {nil, max} -> ["Maximum #{max} characters" | hints]
        {min, max} when min == max -> ["Exactly #{min} characters" | hints]
        {min, max} -> ["#{min}-#{max} characters" | hints]
      end

    # Join all hints with a separator
    case hints do
      [] -> nil
      _ -> Enum.reverse(hints) |> Enum.join(" • ")
    end
  end

  defp generate_validation_hint(_, custom_hint), do: custom_hint

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["page-header", @actions != [] && "page-header-with-actions"]}>
      <div class="page-header-content">
        <h1 class="page-title">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="page-subtitle">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="page-header-actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  slot :inner_block, required: true

  def title(assigns) do
    ~H"""
    <div class="title-wrap">
      <div class="title">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="name">{user.name}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="table-container">
      <table class="data-table">
        <thead class="table-header">
          <tr>
            <th :for={col <- @col}>{col[:label]}</th>
            <th :if={@action != []}>
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={@row_click && "table-cell-clickable"}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="table-actions-cell">
              <div class="table-actions">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="data-list">
      <div :for={item <- @item} class="data-list-item">
        <dt class="data-list-title">{item.title}</dt>
        <dd class="data-list-value">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders pagination controls.

  Pass a function that takes a page number and returns a path.

  ## Examples

      <.pagination
        current_page={1}
        total_pages={5}
        path={fn page -> "/posts?page=" <> to_string(page) end}
      />
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :path, :any, required: true

  def pagination(assigns) do
    ~H"""
    <nav :if={@total_pages > 1} class="pagination" aria-label="Pagination">
      <.link
        :if={@current_page > 1}
        navigate={@path.(@current_page - 1)}
        class="pagination-link pagination-prev"
        aria-label="Previous page"
      >
        ← Previous
      </.link>

      <div class="pagination-pages">
        <%= for page <- page_range(@current_page, @total_pages) do %>
          <%= if page == :gap do %>
            <span class="pagination-gap">…</span>
          <% else %>
            <.link
              navigate={@path.(page)}
              class={["pagination-link", page == @current_page && "pagination-link-active"]}
              aria-label={"Page #{page}"}
              aria-current={page == @current_page && "page"}
            >
              {page}
            </.link>
          <% end %>
        <% end %>
      </div>

      <.link
        :if={@current_page < @total_pages}
        navigate={@path.(@current_page + 1)}
        class="pagination-link pagination-next"
        aria-label="Next page"
      >
        Next →
      </.link>
    </nav>
    """
  end

  defp page_range(_current, total) when total <= 7 do
    1..total
  end

  defp page_range(current, total) do
    cond do
      # Near the beginning
      current <= 4 ->
        [1, 2, 3, 4, 5, :gap, total]

      # Near the end
      current >= total - 3 ->
        [1, :gap, total - 4, total - 3, total - 2, total - 1, total]

      # In the middle
      true ->
        [1, :gap, current - 1, current, current + 1, :gap, total]
    end
  end

  def parse_markdown(body) do
    body
    |> Earmark.as_html!(
      escape: false,
      smartypants: false,
      registered_processors: [
        {"pre", &process_node/1},
        {"h1", &process_heading/1},
        {"h2", &process_heading/1},
        {"h3", &process_heading/1},
        {"h4", &process_heading/1},
        {"h5", &process_heading/1},
        {"h6", &process_heading/1}
      ]
    )
    |> Phoenix.HTML.raw()
  end

  def process_node({"pre", _, [{"code", [], [code], %{}}], _}) do
    {:replace, Makeup.highlight(code, lexer: "plain_text")}
  end

  def process_node({"pre", _, [{"code", [{"class", lang}], [code], %{}}], _}) do
    {:replace, Makeup.highlight(code, lexer: lang)}
  end

  def process_node(node), do: node

  def process_heading({tag, attrs, children, meta}) do
    # Extract text content from children
    text = extract_text(children)
    # Generate slug from text
    slug = slugify(text)
    # Add id attribute
    new_attrs = [{"id", slug} | attrs]
    {tag, new_attrs, children, meta}
  end

  defp extract_text(children) when is_list(children) do
    Enum.map_join(children, "", fn
      text when is_binary(text) -> text
      {_tag, _attrs, nested, _meta} -> extract_text(nested)
    end)
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text(_), do: ""

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  @doc """
  Generates a table of contents from markdown body.
  Returns a list of %{level: integer, text: string, slug: string} maps.
  """
  def generate_toc(body) do
    body
    |> String.split("\n")
    |> Enum.filter(fn line -> String.match?(line, ~r/^[#]{1,6}\s+/) end)
    |> Enum.map(fn line ->
      # Count leading #'s
      level = String.length(Enum.at(String.split(line, " ", parts: 2), 0))
      # Get text after #'s
      text = line |> String.replace(~r/^[#]+\s+/, "") |> String.trim()

      %{
        level: level,
        text: text,
        slug: slugify(text)
      }
    end)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(LocalCafeWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(LocalCafeWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  def float_to_currency(float) do
    :erlang.float_to_binary(float / 100, decimals: 2)
  end
end
