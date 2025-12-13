defmodule LocalCafeWeb.AdminLocationsController do
  use LocalCafeWeb, :controller
  alias LocalCafe.Locations
  alias LocalCafe.Locations.Location

  plug :require_admin

  def index(conn, _params) do
    locations = Locations.list_locations()
    render(conn, :index, locations: locations, page_title: "Admin - Locations")
  end

  def new(conn, _params) do
    changeset = Locations.change_location(%Location{})
    render(conn, :new, changeset: changeset, page_title: "New Location")
  end

  def create(conn, %{"location" => location_params}) do
    # Parse hours from form (if it's a string, split by newlines)
    location_params =
      location_params
      |> parse_hours()
      |> parse_image()

    case Locations.create_location(location_params) do
      {:ok, location} ->
        conn
        |> put_flash(:info, "Location created successfully.")
        |> redirect(to: ~p"/admin/locations/#{location.slug}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, page_title: "New Location")
    end
  end

  def show(conn, %{"slug" => slug}) do
    location = Locations.get_location_by_slug!(slug)
    render(conn, :show, location: location, page_title: location.name)
  end

  def edit(conn, %{"slug" => slug}) do
    location = Locations.get_location_by_slug!(slug)
    changeset = Locations.change_location(location)
    render(conn, :edit, location: location, changeset: changeset, page_title: "Edit #{location.name}")
  end

  def update(conn, %{"slug" => slug, "location" => location_params}) do
    location = Locations.get_location_by_slug!(slug)

    location_params =
      location_params
      |> parse_hours()
      |> parse_image()

    case Locations.update_location(location, location_params) do
      {:ok, location} ->
        conn
        |> put_flash(:info, "Location updated successfully.")
        |> redirect(to: ~p"/admin/locations/#{location.slug}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, location: location, changeset: changeset, page_title: "Edit #{location.name}")
    end
  end

  def delete(conn, %{"slug" => slug}) do
    location = Locations.get_location_by_slug!(slug)
    {:ok, _location} = Locations.delete_location(location)

    conn
    |> put_flash(:info, "Location deleted successfully.")
    |> redirect(to: ~p"/admin/locations")
  end

  defp require_admin(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  defp parse_hours(%{"hours" => hours} = params) when is_binary(hours) do
    hours_array =
      hours
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Map.put(params, "hours", hours_array)
  end

  defp parse_hours(params), do: params

  # Convert images array (from post-image-manager component) to single image map
  defp parse_image(%{"images" => images} = params) when is_binary(images) do
    case Jason.decode(images) do
      {:ok, [first_image | _]} ->
        # Take first image from array and convert to map with string keys
        image_map = %{
          "full_url" => first_image["full_url"],
          "thumb_url" => first_image["thumb_url"]
        }

        params
        |> Map.delete("images")
        |> Map.put("image", image_map)

      {:ok, []} ->
        # No images, set to nil
        params
        |> Map.delete("images")
        |> Map.put("image", nil)

      {:error, _} ->
        Map.delete(params, "images")
    end
  end

  defp parse_image(params), do: Map.delete(params, "images")
end
