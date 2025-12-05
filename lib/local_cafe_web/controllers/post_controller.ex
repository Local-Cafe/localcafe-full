defmodule LocalCafeWeb.PostController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Posts
  alias LocalCafe.Posts.Post
  alias LocalCafe.Posts.Comments

  def index(conn, params) do
    page = String.to_integer(params["page"] || "1")
    search = params["q"]

    opts = [page: page, per_page: 9]
    opts = if search && search != "", do: Keyword.put(opts, :search, search), else: opts

    pagination = Posts.paginate_posts(conn.assigns.current_scope, opts)
    tag_counts = Posts.get_tag_counts(conn.assigns.current_scope)

    render(conn, :index,
      pagination: pagination,
      tag_counts: tag_counts,
      current_tag: nil,
      search_query: search,
      page_title: "Blog",
      page_description:
        "Explore articles and tutorials on web development, programming, and technology."
    )
  end

  def tag(conn, %{"tag" => tag_name} = params) do
    page = String.to_integer(params["page"] || "1")
    search = params["q"]

    opts = [page: page, per_page: 9, tag: tag_name]
    opts = if search && search != "", do: Keyword.put(opts, :search, search), else: opts

    pagination = Posts.paginate_posts(conn.assigns.current_scope, opts)
    tag_counts = Posts.get_tag_counts(conn.assigns.current_scope)

    render(conn, :index,
      pagination: pagination,
      tag_counts: tag_counts,
      current_tag: tag_name,
      search_query: search,
      page_title: "#{String.capitalize(tag_name)} Posts",
      page_description:
        "Browse #{tag_name} articles and posts on LocalCafe.org covering various topics in web development."
    )
  end

  def new(conn, _params) do
    changeset =
      Posts.change_post(conn.assigns.current_scope, %Post{
        user_id: conn.assigns.current_scope.user.id
      })

    render(conn, :new, changeset: changeset, page_title: "New Post")
  end

  def create(conn, %{"post" => post_params}) do
    # Parse images JSON string if present
    post_params = parse_images_param(post_params)

    case Posts.create_post(conn.assigns.current_scope, post_params) do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post created successfully.")
        |> redirect(to: ~p"/posts/#{post}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, page_title: "New Post")
    end
  end

  def show(conn, %{"slug" => slug}) do
    scope = conn.assigns.current_scope

    case Posts.get_post_with_navigation(scope, slug) do
      # Has access - render full post
      {:ok, {post, next_post, previous_post}} ->
        comments = Comments.list_comments_for_post(scope, post.id)
        toc = LocalCafeWeb.CoreComponents.generate_toc(post.body)

        # Get first image for social media preview
        page_image =
          if post.images && length(post.images) > 0 do
            List.first(post.images).full_url
          else
            nil
          end

        conn
        |> put_session(:user_return_to, ~p"/posts/#{post}")
        |> render(:show,
          post: post,
          next_post: next_post,
          previous_post: previous_post,
          comments: comments,
          toc: toc,
          has_access: true,
          page_title: post.title,
          page_description: post.description,
          page_image: page_image,
          page_url: url(~p"/posts/#{post}"),
          page_type: "article"
        )

      # Paid post, user not logged in - show login paywall
      {:error, :requires_login, {post, next_post, previous_post}} ->
        # Get first image for social media preview
        page_image =
          if post.images && length(post.images) > 0 do
            List.first(post.images).full_url
          else
            nil
          end

        conn
        |> put_session(:user_return_to, ~p"/posts/#{post}")
        |> render(:paywall_login,
          post: post,
          next_post: next_post,
          previous_post: previous_post,
          page_title: post.title,
          page_description: post.description,
          page_image: page_image,
          page_url: url(~p"/posts/#{post}"),
          page_type: "article"
        )

      # Paid post, user logged in but hasn't purchased - show purchase paywall
      {:error, :requires_purchase, {post, next_post, previous_post}} ->
        publishable_key = Application.get_env(:local_cafe, :stripe)[:publishable_key]

        # Get first image for social media preview
        page_image =
          if post.images && length(post.images) > 0 do
            List.first(post.images).full_url
          else
            nil
          end

        render(conn, :paywall_purchase,
          post: post,
          next_post: next_post,
          previous_post: previous_post,
          publishable_key: publishable_key,
          page_title: post.title,
          page_description: post.description,
          page_image: page_image,
          page_url: url(~p"/posts/#{post}"),
          page_type: "article"
        )

      # Post not found or not published - 404
      {:error, :not_found} ->
        raise Ecto.NoResultsError, queryable: LocalCafe.Posts.Post
    end
  end

  def edit(conn, %{"slug" => slug}) do
    post = Posts.get_post!(conn.assigns.current_scope, slug)
    changeset = Posts.change_post(conn.assigns.current_scope, post)
    render(conn, :edit, post: post, changeset: changeset, page_title: "Edit #{post.title}")
  end

  def update(conn, %{"slug" => slug, "post" => post_params}) do
    post = Posts.get_post!(conn.assigns.current_scope, slug)

    # Parse images JSON string if present
    post_params = parse_images_param(post_params)

    case Posts.update_post(conn.assigns.current_scope, post, post_params) |> dbg() do
      {:ok, post} ->
        conn
        |> put_flash(:info, "Post updated successfully.")
        |> redirect(to: ~p"/posts/#{post}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, post: post, changeset: changeset, page_title: "Edit #{post.title}")
    end
  end

  def delete(conn, %{"slug" => slug}) do
    post = Posts.get_post!(conn.assigns.current_scope, slug)
    {:ok, _post} = Posts.delete_post(conn.assigns.current_scope, post)

    conn
    |> put_flash(:info, "Post deleted successfully.")
    |> redirect(to: ~p"/posts")
  end

  # Parse images JSON string to array of maps
  defp parse_images_param(%{"images" => images_json} = params) when is_binary(images_json) do
    case Jason.decode(images_json) do
      {:ok, images} when is_list(images) ->
        Map.put(params, "images", images)

      _ ->
        # If parsing fails, remove the images key to avoid validation errors
        Map.delete(params, "images")
    end
  end

  defp parse_images_param(params), do: params
end
