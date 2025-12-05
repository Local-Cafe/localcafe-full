defmodule LocalCafeWeb.AdminCommentsHTML do
  @moduledoc """
  This module contains the admin comments page for moderating comments.

  See the `admin_comments_html` directory for all templates available.
  """
  use LocalCafeWeb, :html

  embed_templates "admin_comments_html/*"
end
