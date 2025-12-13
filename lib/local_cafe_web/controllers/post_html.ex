defmodule LocalCafeWeb.PostHTML do
  use LocalCafeWeb, :html

  embed_templates "post_html/*"

  @doc """
  Renders a post form.

  The form is defined in the template at
  post_html/post_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def post_form(assigns)

  @doc """
  Renders the blog section header.

  ## Examples

      <.blog_header>
        <.title>From the blog</.title>
        <:description>Latest posts and articles</:description>
      </.blog_header>
  """
  slot :title, required: true
  slot :description

  def blog_header(assigns) do
    ~H"""
    <div class="blog-header">
      <h2 class="blog-title">{render_slot(@title)}</h2>
      <p :if={@description != []} class="blog-description">{render_slot(@description)}</p>
    </div>
    """
  end

  @doc """
  Renders a blog post card.

  ## Examples

      <.blog_card
        post={@post}
        image_url="https://example.com/image.jpg"
        category="Article"
        author_name="John Doe"
        author_avatar="https://example.com/avatar.jpg"
      />
  """
  attr :post, :map, required: true

  def blog_card(assigns) do
    # Get primary image or first image if available
    primary_image =
      if assigns.post.images && length(assigns.post.images) > 0 do
        Enum.find(assigns.post.images, & &1.is_primary) || List.first(assigns.post.images)
      else
        nil
      end

    assigns = assign(assigns, :primary_image, primary_image)

    ~H"""
    <div class="blog-card">
      <span :if={@post.draft} class="blog-card-draft-badge">Draft</span>
      <span :if={@post.price} class="blog-card-price-badge">
        ${float_to_currency(@post.price)}
      </span>
      <a :if={@primary_image} href={~p"/posts/#{@post}"} class="blog-card-image-wrapper">
        <img
          class="blog-card-image"
          src={@primary_image.thumb_url}
          alt={"Cover image for #{@post.title}"}
        />
      </a>
      <div class="blog-card-content">
        <a href={~p"/posts/#{@post}"} class="blog-card-title-link">
          <h2 class="blog-card-title">
            {@post.title}
          </h2>
        </a>
        <div class="blog-card-body">
          <p class="blog-card-description">{@post.description}</p>
        </div>
        <div class="blog-card-footer">
          <div class="blog-card-meta">
            <time datetime={Date.to_iso8601(@post.published_at)}>
              {Calendar.strftime(@post.published_at, "%B %d, %Y")}
            </time>
            <div :if={@post.tags != []} class="blog-card-tags">
              <%= for tag <- @post.tags do %>
                <a href={~p"/posts/tags/#{tag.name}"} class="tag">
                  {tag.name}
                </a>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
