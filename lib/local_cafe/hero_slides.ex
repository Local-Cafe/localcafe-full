defmodule LocalCafe.HeroSlides do
  @moduledoc """
  The HeroSlides context.
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo
  alias LocalCafe.HeroSlides.HeroSlide
  alias LocalCafe.Accounts.Scope

  @doc """
  Returns the list of active hero slides for public display.
  Ordered by position, then id.
  """
  def list_active_hero_slides do
    HeroSlide
    |> where([h], h.active == true)
    |> order_by([h], asc: h.position, asc: h.id)
    |> Repo.all()
  end

  @doc """
  Returns the list of all hero slides (admin only).
  Ordered by position, then id.
  """
  def list_hero_slides(%Scope{user: %{admin: true}}) do
    HeroSlide
    |> order_by([h], asc: h.position, asc: h.id)
    |> Repo.all()
  end

  def list_hero_slides(_), do: {:error, :unauthorized}

  @doc """
  Gets a single hero slide (admin only).

  Raises `Ecto.NoResultsError` if the Hero slide does not exist.
  """
  def get_hero_slide!(%Scope{user: %{admin: true}}, id) do
    Repo.get!(HeroSlide, id)
  end

  def get_hero_slide!(_, _), do: raise("Unauthorized")

  @doc """
  Creates a hero slide (admin only).
  """
  def create_hero_slide(scope, attrs \\ %{})

  def create_hero_slide(%Scope{user: %{admin: true}} = scope, attrs) do
    attrs = Map.put(attrs, "user_id", scope.user.id)

    %HeroSlide{}
    |> HeroSlide.changeset(attrs)
    |> Repo.insert()
  end

  def create_hero_slide(_, _), do: {:error, :unauthorized}

  @doc """
  Updates a hero slide (admin only).
  """
  def update_hero_slide(%Scope{user: %{admin: true}}, %HeroSlide{} = hero_slide, attrs) do
    hero_slide
    |> HeroSlide.changeset(attrs)
    |> Repo.update()
  end

  def update_hero_slide(_, _, _), do: {:error, :unauthorized}

  @doc """
  Deletes a hero slide (admin only).
  """
  def delete_hero_slide(%Scope{user: %{admin: true}}, %HeroSlide{} = hero_slide) do
    Repo.delete(hero_slide)
  end

  def delete_hero_slide(_, _), do: {:error, :unauthorized}

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking hero slide changes (admin only).
  """
  def change_hero_slide(scope, hero_slide, attrs \\ %{})

  def change_hero_slide(%Scope{user: %{admin: true}}, %HeroSlide{} = hero_slide, attrs) do
    HeroSlide.changeset(hero_slide, attrs)
  end

  def change_hero_slide(_, _, _), do: raise("Unauthorized")
end
