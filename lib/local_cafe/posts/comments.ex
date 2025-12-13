defmodule LocalCafe.Posts.Comments do
  @moduledoc """
  The Comments context for managing post comments.
  """

  import Ecto.Query
  alias LocalCafe.Repo
  alias LocalCafe.Posts.Comment
  alias LocalCafe.Accounts.Scope

  @doc """
  Gets comments for a post based on scope.

  Admins see all comments. Regular users only see approved comments.
  Comments are ordered by insertion date (oldest first).
  """
  def list_comments_for_post(%Scope{user: %{admin: true}}, post_id) do
    Comment
    |> where([c], c.post_id == ^post_id)
    |> order_by([c], asc: c.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  def list_comments_for_post(_scope, post_id) do
    Comment
    |> where([c], c.post_id == ^post_id and c.approved == true)
    |> order_by([c], asc: c.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Creates a comment on a post.

  If the user is admin or trusted, the comment is automatically approved.
  """
  def create_comment(%Scope{user: user}, post_id, attrs) do
    # Admins and trusted users get auto-approved comments
    auto_approve = user.admin || user.trusted

    %Comment{}
    |> Comment.changeset(
      Map.merge(attrs, %{
        "post_id" => post_id,
        "user_id" => user.id,
        "approved" => auto_approve
      })
    )
    |> Repo.insert()
  end

  @doc """
  Approves a comment and marks the comment author as trusted.
  Only admins can approve comments.
  """
  def approve_comment(%Scope{user: %{admin: true}}, comment_id) do
    comment = Repo.get!(Comment, comment_id) |> Repo.preload(:user)

    Repo.transaction(fn ->
      # Approve the comment
      comment
      |> Ecto.Changeset.change(approved: true)
      |> Repo.update!()

      # Mark the user as trusted
      unless comment.user.admin || comment.user.trusted do
        comment.user
        |> Ecto.Changeset.change(trusted: true)
        |> Repo.update!()
      end

      comment
    end)
  end

  @doc """
  Deletes a comment.
  Only admins or the comment author can delete comments.
  """
  def delete_comment(%Scope{user: user}, comment_id) do
    comment = Repo.get!(Comment, comment_id)

    if user.admin || user.id == comment.user_id do
      Repo.delete(comment)
    else
      {:error, :unauthorized}
    end
  end
end
