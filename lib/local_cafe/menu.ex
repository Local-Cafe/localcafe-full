defmodule LocalCafe.Menu do
  @moduledoc """
  The Menu context.

  Handles all business logic for menu items including:
  - Listing and filtering menu items
  - Creating, updating, deleting menu items (admin only)
  - Tag management
  - Search functionality
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo

  alias LocalCafe.Menu.MenuItem
  alias LocalCafe.Tags.Tag
  alias LocalCafe.Accounts.Scope

  @doc """
  Returns the list of menu items.

  For admins: returns all menu items
  For non-admins: returns only available menu items

  ## Examples

      iex> list_menu_items(scope)
      [%MenuItem{}, ...]

  """
  def list_menu_items(%Scope{user: %{admin: true}}) do
    MenuItem
    |> where([m], m.special == false)
    |> order_by([m], asc: m.position, asc: m.title)
    |> Repo.all()
  end

  def list_menu_items(_) do
    MenuItem
    |> where([m], m.available == true and m.special == false)
    |> order_by([m], asc: m.position, asc: m.title)
    |> Repo.all()
  end

  @doc """
  Returns paginated menu items with metadata.

  For admins: returns all menu items
  For non-admins: returns only available menu items

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 12)
    * `:tag` - Filter by tag name
    * `:location` - Filter by location slug
    * `:search` - Full-text search query

  ## Examples

      iex> paginate_menu_items(scope, page: 1, per_page: 10)
      %{
        menu_items: [%MenuItem{}, ...],
        page: 1,
        per_page: 10,
        total_count: 42,
        total_pages: 5
      }

  """
  def paginate_menu_items(scope, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 12)
    tag = Keyword.get(opts, :tag)
    location = Keyword.get(opts, :location)
    search = Keyword.get(opts, :search)

    query = build_query(scope, tag, location, search)

    total_count = Repo.aggregate(query, :count)
    total_pages = ceil(total_count / per_page)

    menu_items =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> preload([:tags, :locations])
      |> Repo.all()

    %{
      menu_items: menu_items,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  defp build_query(scope, tag, location, search) do
    cond do
      tag && location && search ->
        base_query_for_tag_and_location_and_search(scope, tag, location, search)

      tag && location ->
        base_query_for_tag_and_location(scope, tag, location)

      tag && search ->
        base_query_for_tag_and_search(scope, tag, search)

      location && search ->
        base_query_for_location_and_search(scope, location, search)

      tag ->
        base_query_for_tag(scope, tag)

      location ->
        base_query_for_location(scope, location)

      search ->
        base_query(scope)
        |> apply_search(search)

      true ->
        base_query(scope)
    end
  end

  defp base_query(%Scope{user: %{admin: true}}) do
    from(m in MenuItem,
      where: m.special == false,
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query(_) do
    from(m in MenuItem,
      where: m.available == true and m.special == false,
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_tag(%Scope{user: %{admin: true}}, tag_name) do
    from(m in MenuItem,
      join: t in assoc(m, :tags),
      where: t.name == ^tag_name,
      where: m.special == false,
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_tag(_, tag_name) do
    from(m in MenuItem,
      join: t in assoc(m, :tags),
      where: t.name == ^tag_name,
      where: m.available == true,
      where: m.special == false,
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_tag_and_search(%Scope{user: %{admin: true}}, tag_name, search_term) do
    tag_item_ids =
      from(m in MenuItem,
        join: t in assoc(m, :tags),
        where: t.name == ^tag_name,
        where: m.special == false,
        select: m.id
      )

    MenuItem
    |> where([m], m.id in subquery(tag_item_ids))
    |> apply_search(search_term)
    |> order_by([m], asc: m.position, asc: m.title)
  end

  defp base_query_for_tag_and_search(_, tag_name, search_term) do
    tag_item_ids =
      from(m in MenuItem,
        join: t in assoc(m, :tags),
        where: t.name == ^tag_name,
        where: m.available == true,
        where: m.special == false,
        select: m.id
      )

    MenuItem
    |> where([m], m.id in subquery(tag_item_ids))
    |> apply_search(search_term)
    |> order_by([m], asc: m.position, asc: m.title)
  end

  # Location filtering - return items with the location OR items with no locations (available everywhere)
  defp base_query_for_location(%Scope{user: %{admin: true}}, location_slug) do
    location = LocalCafe.Locations.get_location_by_slug!(location_slug)

    # Get items with this location
    items_with_location =
      from(m in MenuItem,
        join: l in assoc(m, :locations),
        where: l.id == ^location.id,
        where: m.special == false,
        select: m.id
      )

    # Get items with no locations (available everywhere)
    items_with_no_locations =
      from(m in MenuItem,
        left_join: l in assoc(m, :locations),
        where: m.special == false,
        group_by: m.id,
        having: count(l.id) == 0,
        select: m.id
      )

    from(m in MenuItem,
      where: m.id in subquery(items_with_location) or m.id in subquery(items_with_no_locations),
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_location(_, location_slug) do
    location = LocalCafe.Locations.get_location_by_slug!(location_slug)

    items_with_location =
      from(m in MenuItem,
        join: l in assoc(m, :locations),
        where: l.id == ^location.id,
        where: m.available == true,
        where: m.special == false,
        select: m.id
      )

    items_with_no_locations =
      from(m in MenuItem,
        left_join: l in assoc(m, :locations),
        where: m.available == true,
        where: m.special == false,
        group_by: m.id,
        having: count(l.id) == 0,
        select: m.id
      )

    from(m in MenuItem,
      where: m.id in subquery(items_with_location) or m.id in subquery(items_with_no_locations),
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_location_and_search(%Scope{user: %{admin: true}}, location_slug, search_term) do
    base_query_for_location(%Scope{user: %{admin: true}}, location_slug)
    |> apply_search(search_term)
  end

  defp base_query_for_location_and_search(scope, location_slug, search_term) do
    base_query_for_location(scope, location_slug)
    |> apply_search(search_term)
  end

  defp base_query_for_tag_and_location(%Scope{user: %{admin: true}}, tag_name, location_slug) do
    location = LocalCafe.Locations.get_location_by_slug!(location_slug)

    # Items with both tag and location
    items_with_tag_and_location =
      from(m in MenuItem,
        join: t in assoc(m, :tags),
        join: l in assoc(m, :locations),
        where: t.name == ^tag_name,
        where: l.id == ^location.id,
        where: m.special == false,
        select: m.id
      )

    # Items with tag and no locations
    items_with_tag_and_no_locations =
      from(m in MenuItem,
        join: t in assoc(m, :tags),
        left_join: l in assoc(m, :locations),
        where: t.name == ^tag_name,
        where: m.special == false,
        group_by: m.id,
        having: count(l.id) == 0,
        select: m.id
      )

    from(m in MenuItem,
      where:
        m.id in subquery(items_with_tag_and_location) or
          m.id in subquery(items_with_tag_and_no_locations),
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_tag_and_location(_, tag_name, location_slug) do
    location = LocalCafe.Locations.get_location_by_slug!(location_slug)

    items_with_tag_and_location =
      from(m in MenuItem,
        join: t in assoc(m, :tags),
        join: l in assoc(m, :locations),
        where: t.name == ^tag_name,
        where: l.id == ^location.id,
        where: m.available == true,
        where: m.special == false,
        select: m.id
      )

    items_with_tag_and_no_locations =
      from(m in MenuItem,
        join: t in assoc(m, :tags),
        left_join: l in assoc(m, :locations),
        where: t.name == ^tag_name,
        where: m.available == true,
        where: m.special == false,
        group_by: m.id,
        having: count(l.id) == 0,
        select: m.id
      )

    from(m in MenuItem,
      where:
        m.id in subquery(items_with_tag_and_location) or
          m.id in subquery(items_with_tag_and_no_locations),
      order_by: [asc: m.position, asc: m.title]
    )
  end

  defp base_query_for_tag_and_location_and_search(
         %Scope{user: %{admin: true}} = scope,
         tag_name,
         location_slug,
         search_term
       ) do
    base_query_for_tag_and_location(scope, tag_name, location_slug)
    |> apply_search(search_term)
  end

  defp base_query_for_tag_and_location_and_search(scope, tag_name, location_slug, search_term) do
    base_query_for_tag_and_location(scope, tag_name, location_slug)
    |> apply_search(search_term)
  end

  defp apply_search(query, search_term) when is_binary(search_term) and search_term != "" do
    query
    |> where(
      [m],
      fragment(
        """
        to_tsvector(
          'english',
          coalesce(?, '') || ' ' ||
          coalesce(?, '')
        ) @@ plainto_tsquery('english', ?)
        OR
        word_similarity(?, ? || ' ' || coalesce(?, '')) > 0.3
        """,
        m.title,
        m.description,
        ^search_term,
        ^search_term,
        m.title,
        m.description
      )
    )
  end

  defp apply_search(query, _), do: query

  @doc """
  Gets a single menu item by slug.

  Raises `Ecto.NoResultsError` if the menu item does not exist or user doesn't have access.

  For admins: can access any menu item
  For non-admins: can only access available menu items

  ## Examples

      iex> get_menu_item!(scope, "coffee")
      %MenuItem{}

      iex> get_menu_item!(scope, "nonexistent")
      ** (Ecto.NoResultsError)

  """
  def get_menu_item!(%Scope{user: %{admin: true}}, slug) do
    MenuItem
    |> where([m], m.slug == ^slug)
    |> preload([:tags, :locations])
    |> Repo.one!()
  end

  def get_menu_item!(_, slug) do
    MenuItem
    |> where([m], m.slug == ^slug)
    |> where([m], m.available == true)
    |> preload([:tags, :locations])
    |> Repo.one!()
  end

  @doc """
  Creates a menu item.

  Admin only.

  ## Examples

      iex> create_menu_item(admin_scope, %{field: value})
      {:ok, %MenuItem{}}

      iex> create_menu_item(admin_scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_menu_item(scope, attrs \\ %{})

  def create_menu_item(%Scope{user: %{admin: true}} = scope, attrs) do
    %MenuItem{}
    |> MenuItem.changeset(attrs, scope)
    |> Repo.insert()
  end

  def create_menu_item(_, _attrs) do
    {:error, :unauthorized}
  end

  @doc """
  Updates a menu item.

  Admin only.

  ## Examples

      iex> update_menu_item(admin_scope, menu_item, %{field: new_value})
      {:ok, %MenuItem{}}

      iex> update_menu_item(admin_scope, menu_item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_menu_item(%Scope{user: %{admin: true}} = scope, %MenuItem{} = menu_item, attrs) do
    menu_item
    |> MenuItem.changeset(attrs, scope)
    |> Repo.update()
  end

  def update_menu_item(_, _, _attrs) do
    {:error, :unauthorized}
  end

  @doc """
  Deletes a menu item.

  Admin only.

  ## Examples

      iex> delete_menu_item(admin_scope, menu_item)
      {:ok, %MenuItem{}}

      iex> delete_menu_item(admin_scope, menu_item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_menu_item(%Scope{user: %{admin: true}}, %MenuItem{} = menu_item) do
    Repo.delete(menu_item)
  end

  def delete_menu_item(_, _) do
    {:error, :unauthorized}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking menu item changes.

  ## Examples

      iex> change_menu_item(scope, menu_item)
      %Ecto.Changeset{data: %MenuItem{}}

  """
  def change_menu_item(
        %Scope{user: %{admin: true}} = scope,
        %MenuItem{} = menu_item,
        attrs \\ %{}
      ) do
    MenuItem.changeset(menu_item, attrs, scope)
  end

  @doc """
  Returns counts of menu items per tag.

  ## Examples

      iex> get_tag_counts()
      [{"vegetarian", 5}, {"gluten-free", 3}]

  """
  def get_tag_counts do
    from(t in Tag,
      join: m in assoc(t, :menu_items),
      group_by: t.name,
      select: {t.name, count(m.id)},
      order_by: [desc: count(m.id)]
    )
    |> Repo.all()
  end

  @doc """
  Returns statistics for the admin dashboard.

  ## Examples

      iex> get_menu_stats()
      %{total: 42, available: 40, unavailable: 2}

  """
  def get_menu_stats do
    total = Repo.aggregate(MenuItem, :count)
    available = Repo.aggregate(from(m in MenuItem, where: m.available == true), :count)

    %{
      total: total,
      available: available,
      unavailable: total - available
    }
  end

  @doc """
  Returns the list of menu items marked as specials.

  For admins: returns all specials
  For non-admins: returns only available specials

  ## Examples

      iex> list_specials(scope)
      [%MenuItem{}, ...]

  """
  def list_specials(%Scope{user: %{admin: true}}) do
    MenuItem
    |> where([m], m.special == true)
    |> order_by([m], asc: m.position, asc: m.title)
    |> preload([:tags, :locations])
    |> Repo.all()
  end

  def list_specials(_) do
    MenuItem
    |> where([m], m.special == true and m.available == true)
    |> order_by([m], asc: m.position, asc: m.title)
    |> preload([:tags, :locations])
    |> Repo.all()
  end
end
