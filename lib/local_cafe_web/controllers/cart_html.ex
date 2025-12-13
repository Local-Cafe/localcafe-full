defmodule LocalCafeWeb.CartHTML do
  @moduledoc """
  This module contains pages rendered by CartController.
  """
  use LocalCafeWeb, :html

  embed_templates "cart_html/*"
end
