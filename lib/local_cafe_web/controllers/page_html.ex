defmodule LocalCafeWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use LocalCafeWeb, :html

  embed_templates "page_html/*"

  @doc """
  Builds a pagination URL for the home page with optional tag and location filters.
  """
  def build_home_pagination_url(page, current_tag, current_location \\ nil) do
    query_params = %{"page" => page}

    query_params =
      if current_tag,
        do: Map.put(query_params, "tag", current_tag),
        else: query_params

    query_params =
      if current_location,
        do: Map.put(query_params, "location", current_location.slug),
        else: query_params

    "#{~p"/?#{query_params}"}#menu"
  end
end
