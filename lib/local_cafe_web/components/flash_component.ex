defmodule LocalCafeWeb.FlashComponent do
  @moduledoc """
  Flash message web component using light DOM pattern.

  This component uses a custom element (`<flash-message>`) styled via external CSS
  in `assets/css/components/flash.css`. All styles use design tokens for maintainability.

  **Why Light DOM?** Flash messages are interactive UI components that benefit from
  design token theming. They don't contain SEO-critical content. See CLAUDE.md
  "Web Components Pattern Selection" for guidance on Light DOM vs Shadow DOM.

  JavaScript enhancement is optional and loaded from `assets/js/components/flash-message.js`.

  Inspired by Kelp UI's approach: https://github.com/cferdinandi/kelp
  """
  use Phoenix.Component
  use Gettext, backend: LocalCafeWeb.Gettext

  @doc """
  Renders a flash message as a web component.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      <.flash kind={:info}>Welcome back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <flash-message
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      data-kind={@kind}
      data-phx-flash-key={@kind}
      role="alert"
      {@rest}
    >
      <span :if={@kind == :info} class="flash-icon" aria-hidden="true">ℹ</span>
      <span :if={@kind == :error} class="flash-icon" aria-hidden="true">⚠</span>
      <div class="flash-content">
        <p :if={@title} class="flash-title">{@title}</p>
        <p class="flash-message">{msg}</p>
      </div>
      <button type="button" class="flash-close" aria-label={gettext("close")}>×</button>
    </flash-message>
    """
  end
end
