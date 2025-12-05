defmodule LocalCafeWeb.PaymentHTML do
  @moduledoc """
  This module contains pages rendered by PaymentController.

  See the `payment_html` directory for all templates available.
  """
  use LocalCafeWeb, :html

  embed_templates "payment_html/*"
end
