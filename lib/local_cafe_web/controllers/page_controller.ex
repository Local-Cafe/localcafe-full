defmodule LocalCafeWeb.PageController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Posts
  alias LocalCafe.Menu
  alias LocalCafe.Locations
  alias LocalCafe.HeroSlides

  def home(conn, params) do
    title = "Welcome to LocalCafe.org"
    scope = conn.assigns.current_scope

    # Get hero slides
    hero_slides = HeroSlides.list_active_hero_slides()

    # Get specials
    specials = Menu.list_specials(scope)

    # Get menu items with optional tag and location filters
    current_tag = params["tag"]
    current_location_slug = params["location"]
    page = String.to_integer(params["page"] || "1")

    menu_opts = [page: page, per_page: 100]
    menu_opts = if current_tag, do: Keyword.put(menu_opts, :tag, current_tag), else: menu_opts

    menu_opts =
      if current_location_slug,
        do: Keyword.put(menu_opts, :location, current_location_slug),
        else: menu_opts

    menu_pagination = Menu.paginate_menu_items(scope, menu_opts)
    tag_counts = Menu.get_tag_counts()
    locations = Locations.list_active_locations()

    # Get latest blog posts
    latest_posts = Posts.get_latest_posts(scope, 3)

    current_location =
      if current_location_slug,
        do: Locations.get_location_by_slug!(current_location_slug),
        else: nil

    render(conn, :home,
      hero_slides: hero_slides,
      specials: specials,
      menu_pagination: menu_pagination,
      tag_counts: tag_counts,
      locations: locations,
      current_tag: current_tag,
      current_location: current_location,
      latest_posts: latest_posts,
      title: title,
      page_title: "Home",
      page_description: "LocalCafe.org - A full featured site for restaurants and cafes"
    )
  end
end
