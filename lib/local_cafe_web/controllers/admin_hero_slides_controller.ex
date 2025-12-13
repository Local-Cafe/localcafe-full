defmodule LocalCafeWeb.AdminHeroSlidesController do
  use LocalCafeWeb, :controller
  alias LocalCafe.HeroSlides
  alias LocalCafe.HeroSlides.HeroSlide

  plug :require_admin

  def index(conn, _params) do
    hero_slides = HeroSlides.list_hero_slides(conn.assigns.current_scope)
    render(conn, :index, hero_slides: hero_slides, page_title: "Admin - Hero Slides")
  end

  def new(conn, _params) do
    changeset =
      HeroSlides.change_hero_slide(conn.assigns.current_scope, %HeroSlide{
        user_id: conn.assigns.current_scope.user.id
      })

    render(conn, :new, changeset: changeset, page_title: "New Hero Slide")
  end

  def create(conn, %{"hero_slide" => hero_slide_params}) do
    # Parse image from JSON
    hero_slide_params = parse_image(hero_slide_params)

    case HeroSlides.create_hero_slide(conn.assigns.current_scope, hero_slide_params) do
      {:ok, _hero_slide} ->
        conn
        |> put_flash(:info, "Hero slide created successfully.")
        |> redirect(to: ~p"/admin/hero-slides")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset, page_title: "New Hero Slide")
    end
  end

  def edit(conn, %{"id" => id}) do
    hero_slide = HeroSlides.get_hero_slide!(conn.assigns.current_scope, id)
    changeset = HeroSlides.change_hero_slide(conn.assigns.current_scope, hero_slide)

    render(conn, :edit,
      hero_slide: hero_slide,
      changeset: changeset,
      page_title: "Edit Hero Slide"
    )
  end

  def update(conn, %{"id" => id, "hero_slide" => hero_slide_params}) do
    hero_slide = HeroSlides.get_hero_slide!(conn.assigns.current_scope, id)

    # Parse image from JSON
    hero_slide_params = parse_image(hero_slide_params)

    case HeroSlides.update_hero_slide(conn.assigns.current_scope, hero_slide, hero_slide_params) do
      {:ok, _hero_slide} ->
        conn
        |> put_flash(:info, "Hero slide updated successfully.")
        |> redirect(to: ~p"/admin/hero-slides")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          hero_slide: hero_slide,
          changeset: changeset,
          page_title: "Edit Hero Slide"
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    hero_slide = HeroSlides.get_hero_slide!(conn.assigns.current_scope, id)
    {:ok, _hero_slide} = HeroSlides.delete_hero_slide(conn.assigns.current_scope, hero_slide)

    conn
    |> put_flash(:info, "Hero slide deleted successfully.")
    |> redirect(to: ~p"/admin/hero-slides")
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

  # Convert images array (from post-image-manager component) to single image map
  defp parse_image(%{"images" => images} = params) when is_binary(images) do
    case Jason.decode(images) do
      {:ok, [first_image | _]} ->
        # Take first image from array and convert to map with string keys
        image_map = %{
          "full_url" => first_image["full_url"],
          "thumb_url" => first_image["thumb_url"],
          "filename" => first_image["filename"]
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
