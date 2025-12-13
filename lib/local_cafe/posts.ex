defmodule LocalCafe.Posts do
  @moduledoc """
  The Posts context.
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo

  alias LocalCafe.Posts.Post
  alias LocalCafe.Tags.Tag
  alias LocalCafe.Posts.PostPurchase
  alias LocalCafe.Accounts.Scope

  @doc """
  Returns the list of posts.

  For admins: returns all posts
  For non-admins: returns only published posts (not drafts) with published_at <= today

  ## Examples

      iex> list_posts(scope)
      [%Post{}, ...]

  """
  def list_posts(%Scope{user: %{admin: true}}) do
    Post
    |> order_by([p], desc: p.published_at)
    |> Repo.all()
  end

  def list_posts(_) do
    today = Date.utc_today()

    Post
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
    |> order_by([p], desc: p.published_at)
    |> Repo.all()
  end

  @doc """
  Returns true if there are any published posts available to the public.

  ## Examples

      iex> has_published_posts?()
      true

  """
  def has_published_posts? do
    today = Date.utc_today()

    Post
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
    |> limit(1)
    |> Repo.exists?()
  end

  @doc """
  Returns the latest posts.

  For admins: returns all posts
  For non-admins: returns only published posts (not drafts) with published_at <= today

  ## Examples

      iex> get_latest_posts(scope, 3)
      [%Post{}, ...]

  """
  def get_latest_posts(%Scope{user: %{admin: true}}, limit) do
    Post
    |> order_by([p], desc: p.published_at)
    |> limit(^limit)
    |> preload(:tags)
    |> Repo.all()
  end

  def get_latest_posts(_, limit) do
    today = Date.utc_today()

    Post
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
    |> order_by([p], desc: p.published_at)
    |> limit(^limit)
    |> preload(:tags)
    |> Repo.all()
  end

  @doc """
  Returns paginated posts with metadata.

  For admins: returns all posts
  For non-admins: returns only published posts (not drafts) with published_at <= today

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 9)
    * `:tag` - Filter by tag name
    * `:search` - Full-text search query

  ## Examples

      iex> paginate_posts(scope, page: 1, per_page: 10)
      %{
        posts: [%Post{}, ...],
        page: 1,
        per_page: 10,
        total_count: 42,
        total_pages: 5
      }

  """
  def paginate_posts(scope, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 9)
    tag = Keyword.get(opts, :tag)
    search = Keyword.get(opts, :search)

    query = build_query(scope, tag, search)

    total_count = Repo.aggregate(query, :count)
    total_pages = ceil(total_count / per_page)

    posts =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> preload(:tags)
      |> Repo.all()

    %{
      posts: posts,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  defp build_query(scope, tag, search) do
    cond do
      tag && search ->
        # When both tag and search are present, use a subquery approach
        # so both indexes can be used independently
        base_query_for_tag_and_search(scope, tag, search)

      tag ->
        base_query_for_tag(scope, tag)

      search ->
        base_query(scope)
        |> apply_search(search)

      true ->
        base_query(scope)
    end
  end

  defp base_query_for_tag_and_search(%Scope{user: %{admin: true}}, tag_name, search_term) do
    # Get post IDs from tag filter
    tag_post_ids =
      from(p in Post,
        join: t in assoc(p, :tags),
        where: t.name == ^tag_name,
        select: p.id
      )

    # Apply search on those posts using the GIN index
    Post
    |> where([p], p.id in subquery(tag_post_ids))
    |> apply_search(search_term)
    |> order_by([p], desc: p.published_at)
  end

  defp base_query_for_tag_and_search(_, tag_name, search_term) do
    today = Date.utc_today()

    # Get post IDs from tag filter (published only)
    tag_post_ids =
      from(p in Post,
        join: t in assoc(p, :tags),
        where: t.name == ^tag_name,
        where: p.draft == false,
        where: p.published_at <= ^today,
        select: p.id
      )

    # Apply search on those posts using the GIN index
    Post
    |> where([p], p.id in subquery(tag_post_ids))
    |> apply_search(search_term)
    |> order_by([p], desc: p.published_at)
  end

  defp apply_search(query, search_term) when is_binary(search_term) and search_term != "" do
    # Use a hybrid approach: full-text search OR trigram word_similarity
    # word_similarity is designed for finding short strings within longer text
    # Using a threshold of 0.3 for good typo tolerance
    query
    |> where(
      [p],
      fragment(
        """
        to_tsvector(
          'english',
          coalesce(?, '') || ' ' ||
          coalesce(?, '') || ' ' ||
          coalesce(?, '')
        ) @@ plainto_tsquery('english', ?)
        OR
        word_similarity(?, ? || ' ' || coalesce(?, '') || ' ' || coalesce(?, '')) > 0.3
        """,
        p.title,
        p.description,
        p.body,
        ^search_term,
        ^search_term,
        p.title,
        p.description,
        p.body
      )
    )
  end

  defp apply_search(query, _), do: query

  defp base_query(%Scope{user: %{admin: true}}) do
    Post
    |> order_by([p], desc: p.published_at)
  end

  defp base_query(_) do
    today = Date.utc_today()

    Post
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
    |> order_by([p], desc: p.published_at)
  end

  defp base_query_for_tag(%Scope{user: %{admin: true}}, tag_name) do
    Post
    |> join(:inner, [p], t in assoc(p, :tags))
    |> where([p, t], t.name == ^tag_name)
    |> order_by([p], desc: p.published_at)
  end

  defp base_query_for_tag(_, tag_name) do
    today = Date.utc_today()

    Post
    |> join(:inner, [p], t in assoc(p, :tags))
    |> where([p, t], t.name == ^tag_name)
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
    |> order_by([p], desc: p.published_at)
  end

  # Base filter without ordering (for post queries)
  defp base_filter(%Scope{user: %{admin: true}}) do
    Post
  end

  defp base_filter(_) do
    today = Date.utc_today()

    Post
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
  end

  @doc """
  Gets tag counts for all tags used in published posts.

  Returns a list of `{tag_name, count}` tuples ordered by count descending.

  ## Examples

      iex> get_tag_counts(scope)
      [{"elixir", 5}, {"phoenix", 3}, {"web", 2}]

  """
  def get_tag_counts(%Scope{user: %{admin: true}}) do
    from(t in Tag,
      join: pt in "post_tags",
      on: pt.tag_id == t.id,
      group_by: t.name,
      select: {t.name, count(pt.post_id)},
      order_by: [desc: count(pt.post_id)]
    )
    |> Repo.all()
  end

  def get_tag_counts(_scope) do
    today = Date.utc_today()

    from(t in Tag,
      join: pt in "post_tags",
      on: pt.tag_id == t.id,
      join: p in Post,
      on: p.id == pt.post_id,
      where: p.draft == false and p.published_at <= ^today,
      group_by: t.name,
      select: {t.name, count(pt.post_id)},
      order_by: [desc: count(pt.post_id)]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single post by slug with next and previous posts, checking access based on scope.

  Returns:
  - `{:ok, {post, next, prev}}` if post found and user has access
  - `{:error, :not_found}` if post doesn't exist or is not published
  - `{:error, :requires_login}` if post is paid and user is not logged in
  - `{:error, :requires_purchase}` if post is paid and user hasn't purchased it

  ## Examples

      iex> get_post_with_navigation(admin_scope, "my-post-slug")
      {:ok, {%Post{}, %Post{}, %Post{}}}

      iex> get_post_with_navigation(nil, "paid-post")
      {:error, :requires_login}

  """
  # Admin: access all posts
  def get_post_with_navigation(%Scope{user: %{admin: true}} = scope, slug) do
    case get_post_navigation_data(scope, slug) do
      {:ok, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  # Logged in user: check if free or purchased
  def get_post_with_navigation(%Scope{user: user} = scope, slug) do
    case get_post_navigation_data(scope, slug) do
      {:ok, {post, next_post, prev_post}} ->
        cond do
          # Free post - has access
          is_nil(post.price) ->
            {:ok, {post, next_post, prev_post}}

          # Paid post - check if purchased
          user_has_access?(post, user.id) ->
            {:ok, {post, next_post, prev_post}}

          # Paid post - not purchased
          true ->
            {:error, :requires_purchase, {post, next_post, prev_post}}
        end

      {:error, _} = error ->
        error
    end
  end

  # Guest user: check if free post
  def get_post_with_navigation(nil, slug) do
    case get_post_navigation_data(nil, slug) do
      {:ok, {post, next_post, prev_post}} ->
        if is_nil(post.price) do
          {:ok, {post, next_post, prev_post}}
        else
          {:error, :requires_login, {post, next_post, prev_post}}
        end

      {:error, _} = error ->
        error
    end
  end

  defp get_post_navigation_data(scope, slug) do
    # Single query using window functions and self-joins
    subquery =
      from p in base_filter(scope),
        select: %{
          id: p.id,
          slug: p.slug,
          prev_id: over(lag(p.id), :w),
          next_id: over(lead(p.id), :w)
        },
        windows: [w: [order_by: [desc: p.published_at]]]

    query =
      from s in subquery(subquery),
        join: current in Post,
        on: s.id == current.id,
        left_join: prev in Post,
        on: s.prev_id == prev.id,
        left_join: next in Post,
        on: s.next_id == next.id,
        where: s.slug == ^slug,
        select: {current, next, prev}

    case Repo.one(query) do
      {current, next, prev} ->
        current = Repo.preload(current, :tags)
        next = if next, do: Repo.preload(next, :tags), else: nil
        prev = if prev, do: Repo.preload(prev, :tags), else: nil
        {:ok, {current, next, prev}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets a single post by slug.

  For admins: returns any post
  For non-admins: returns only published posts (not drafts) with published_at <= today

  Raises `Ecto.NoResultsError` if the Post does not exist or is not accessible.

  ## Examples

      iex> get_post!(scope, "my-post-slug")
      %Post{}

      iex> get_post!(scope, "nonexistent")
      ** (Ecto.NoResultsError)

  """
  def get_post!(%Scope{user: %{admin: true}}, slug) do
    Post
    |> Repo.get_by!(slug: slug)
    |> Repo.preload(:tags)
  end

  def get_post!(_, slug) do
    today = Date.utc_today()

    Post
    |> where([p], p.slug == ^slug)
    |> where([p], p.draft == false)
    |> where([p], p.published_at <= ^today)
    |> Repo.one!()
    |> Repo.preload(:tags)
  end

  @doc """
  Creates a post.

  Only admins can create posts.

  ## Examples

      iex> create_post(scope, %{field: value})
      {:ok, %Post{}}

      iex> create_post(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(%Scope{user: %{admin: true}} = scope, attrs) do
    with {:ok, post = %Post{}} <-
           %Post{}
           |> Post.changeset(attrs, scope)
           |> Repo.insert() do
      {:ok, post}
    end
  end

  @doc """
  Updates a post.

  Only admins who own the post can update it.

  ## Examples

      iex> update_post(scope, post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(scope, post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Scope{user: %{admin: true}} = scope, %Post{} = post, attrs) do
    true = post.user_id == scope.user.id

    with {:ok, post = %Post{}} <-
           post
           |> Post.changeset(attrs, scope)
           |> Repo.update() do
      {:ok, post}
    end
  end

  @doc """
  Deletes a post.

  Only admins who own the post can delete it.

  ## Examples

      iex> delete_post(scope, post)
      {:ok, %Post{}}

      iex> delete_post(scope, post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Scope{user: %{admin: true}} = scope, %Post{} = post) do
    true = post.user_id == scope.user.id

    with {:ok, post = %Post{}} <-
           Repo.delete(post) do
      {:ok, post}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  Only admins who own the post can change it.

  ## Examples

      iex> change_post(scope, post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Scope{user: %{admin: true}} = scope, %Post{} = post, attrs \\ %{}) do
    true = post.user_id == scope.user.id

    Post.changeset(post, attrs, scope)
  end

  @doc """
  Returns post statistics for the admin dashboard.
  """
  def get_post_stats do
    total_posts = Repo.aggregate(Post, :count, :id)
    published_posts = Repo.aggregate(from(p in Post, where: p.draft == false), :count, :id)
    draft_posts = Repo.aggregate(from(p in Post, where: p.draft == true), :count, :id)

    %{
      total: total_posts,
      published: published_posts,
      drafts: draft_posts
    }
  end

  @doc """
  Checks if a user has access to view a post.

  Returns true if:
  - Post is free (price is nil)
  - User is admin
  - User has purchased the post

  ## Examples

      iex> user_has_access?(post, user_id)
      true

  """
  def user_has_access?(%Post{price: nil}, _user_id), do: true
  def user_has_access?(_post, nil), do: false

  def user_has_access?(%Post{id: post_id}, user_id) do
    from(pp in PostPurchase,
      where: pp.post_id == ^post_id and pp.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @doc """
  Creates a post purchase record.

  ## Examples

      iex> create_post_purchase(%{user_id: user_id, post_id: post_id, amount: 999})
      {:ok, %PostPurchase{}}

  """
  def create_post_purchase(attrs \\ %{}) do
    %PostPurchase{}
    |> PostPurchase.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a post purchase by user and post.

  Returns nil if not found.

  ## Examples

      iex> get_post_purchase(user_id, post_id)
      %PostPurchase{}

  """
  def get_post_purchase(user_id, post_id) do
    from(pp in PostPurchase,
      where: pp.user_id == ^user_id and pp.post_id == ^post_id
    )
    |> Repo.one()
  end
end
