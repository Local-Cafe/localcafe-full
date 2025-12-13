defmodule LocalCafeWeb.CheckoutHTML do
  @moduledoc """
  This module contains pages rendered by CheckoutController.
  """
  use LocalCafeWeb, :html

  embed_templates "checkout_html/*"
end
