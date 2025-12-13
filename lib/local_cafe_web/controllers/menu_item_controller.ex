defmodule LocalCafeWeb.MenuItemController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Menu
  alias LocalCafe.Menu.MenuItem
  alias LocalCafe.Locations

  def show(conn, %{"slug" => slug}) do
    menu_item = Menu.get_menu_item!(conn.assigns.current_scope, slug)

    # Get primary image or first image for display
    primary_image =
      if menu_item.images && length(menu_item.images) > 0 do
        Enum.find(menu_item.images, &(&1.is_primary == true)) || List.first(menu_item.images)
      else
        nil
      end

    # Get page image for social media
    page_image = if primary_image, do: primary_image.full_url, else: nil

    render(conn, :show,
      menu_item: menu_item,
      primary_image: primary_image,
      page_title: menu_item.title,
      page_description: menu_item.description,
      page_image: page_image,
      page_url: url(~p"/menu/#{menu_item}")
    )
  end

  def new(conn, _params) do
    changeset =
      Menu.change_menu_item(conn.assigns.current_scope, %MenuItem{
        user_id: conn.assigns.current_scope.user.id
      })

    locations = Locations.list_locations()

    render(conn, :new,
      changeset: changeset,
      locations: locations,
      page_title: "New Menu Item"
    )
  end

  def create(conn, %{"menu_item" => menu_item_params}) do
    # Parse JSON params
    menu_item_params = parse_json_params(menu_item_params)

    case Menu.create_menu_item(conn.assigns.current_scope, menu_item_params) do
      {:ok, menu_item} ->
        conn
        |> put_flash(:info, "Menu item created successfully.")
        |> redirect(to: ~p"/menu/#{menu_item}")

      {:error, %Ecto.Changeset{} = changeset} ->
        locations = Locations.list_locations()
        render(conn, :new,
          changeset: changeset,
          locations: locations,
          page_title: "New Menu Item"
        )
    end
  end

  def edit(conn, %{"slug" => slug}) do
    menu_item = Menu.get_menu_item!(conn.assigns.current_scope, slug)
    changeset = Menu.change_menu_item(conn.assigns.current_scope, menu_item)
    locations = Locations.list_locations()

    render(conn, :edit,
      menu_item: menu_item,
      changeset: changeset,
      locations: locations,
      page_title: "Edit #{menu_item.title}"
    )
  end

  def update(conn, %{"slug" => slug, "menu_item" => menu_item_params}) do
    menu_item = Menu.get_menu_item!(conn.assigns.current_scope, slug)

    # Parse JSON params
    menu_item_params = parse_json_params(menu_item_params)

    case Menu.update_menu_item(conn.assigns.current_scope, menu_item, menu_item_params) do
      {:ok, menu_item} ->
        conn
        |> put_flash(:info, "Menu item updated successfully.")
        |> redirect(to: ~p"/menu/#{menu_item}")

      {:error, %Ecto.Changeset{} = changeset} ->
        locations = Locations.list_locations()
        render(conn, :edit,
          menu_item: menu_item,
          changeset: changeset,
          locations: locations,
          page_title: "Edit #{menu_item.title}"
        )
    end
  end

  def delete(conn, %{"slug" => slug}) do
    menu_item = Menu.get_menu_item!(conn.assigns.current_scope, slug)
    {:ok, _menu_item} = Menu.delete_menu_item(conn.assigns.current_scope, menu_item)

    conn
    |> put_flash(:info, "Menu item deleted successfully.")
    |> redirect(to: ~p"/menu")
  end

  # Parse JSON strings for images, prices, and variants
  defp parse_json_params(params) do
    params
    |> parse_json_field("images")
    |> parse_json_field("prices")
    |> parse_json_field("variants")
  end

  defp parse_json_field(params, field) do
    case Map.get(params, field) do
      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, decoded} when is_list(decoded) ->
            Map.put(params, field, decoded)

          _ ->
            Map.delete(params, field)
        end

      _ ->
        params
    end
  end
end
