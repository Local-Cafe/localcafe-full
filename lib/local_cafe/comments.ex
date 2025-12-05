defmodule LocalCafe.Comments do
  @moduledoc """
  Unified Comments context for managing both post and photo comments.
  """

  import Ecto.Query
  alias LocalCafe.Repo
  alias LocalCafe.Posts.Comment, as: PostComment
  alias LocalCafe.Accounts.Scope

  @doc """
  Lists all pending comments (not approved) from both posts.
  Only for admins.
  """
  def list_pending_comments(%Scope{user: %{admin: true}}) do
    post_comments =
      PostComment
      |> where([c], c.approved == false)
      |> order_by([c], desc: c.inserted_at)
      |> preload([:user, :post])
      |> Repo.all()
      |> Enum.map(&add_comment_type(&1, :post))

    # Merge and sort by inserted_at desc
    post_comments
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
  end

  def list_pending_comments(_scope), do: []

  @doc """
  Lists all approved comments from both posts.
  Only for admins.
  """
  def list_approved_comments(%Scope{user: %{admin: true}}) do
    post_comments =
      PostComment
      |> where([c], c.approved == true)
      |> order_by([c], desc: c.inserted_at)
      |> preload([:user, :post])
      |> Repo.all()
      |> Enum.map(&add_comment_type(&1, :post))

    # Merge and sort by inserted_at desc
    post_comments
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
  end

  def list_approved_comments(_scope), do: []

  @doc """
  Lists all comments from both posts and photos.
  Only for admins.
  """
  def list_all_comments(%Scope{user: %{admin: true}}) do
    post_comments =
      PostComment
      |> order_by([c], desc: c.inserted_at)
      |> preload([:user, :post])
      |> Repo.all()
      |> Enum.map(&add_comment_type(&1, :post))

    # Merge and sort by inserted_at desc
    post_comments
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
  end

  def list_all_comments(_scope), do: []

  @doc """
  Lists all comments from a specific user.
  Only for admins.
  """
  def list_comments_by_user(%Scope{user: %{admin: true}}, user_id) do
    post_comments =
      PostComment
      |> where([c], c.user_id == ^user_id)
      |> order_by([c], desc: c.inserted_at)
      |> preload([:user, :post])
      |> Repo.all()
      |> Enum.map(&add_comment_type(&1, :post))

    # Merge and sort by inserted_at desc
    post_comments
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
  end

  def list_comments_by_user(_scope, _user_id), do: []

  @doc """
  Counts the total number of comments from a specific user.
  Only for admins.
  """
  def count_comments_by_user(%Scope{user: %{admin: true}}, user_id) do
    post_count =
      PostComment
      |> where([c], c.user_id == ^user_id)
      |> Repo.aggregate(:count, :id)

    post_count
  end

  def count_comments_by_user(_scope, _user_id), do: 0

  @doc """
  Returns comment statistics for the admin dashboard.
  Only for admins.
  """
  def get_comment_stats(%Scope{user: %{admin: true}}) do
    post_comments_total = Repo.aggregate(PostComment, :count, :id)

    post_comments_pending =
      Repo.aggregate(from(c in PostComment, where: c.approved == false), :count, :id)

    post_comments_approved =
      Repo.aggregate(from(c in PostComment, where: c.approved == true), :count, :id)

    %{
      total: post_comments_total,
      pending: post_comments_pending,
      approved: post_comments_approved
    }
  end

  def get_comment_stats(_scope), do: %{total: 0, pending: 0, approved: 0}

  # Helper to add comment type to the struct
  defp add_comment_type(comment, type) do
    Map.put(comment, :comment_type, type)
  end
end
