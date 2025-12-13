defmodule LocalCafe.Locations do
  @moduledoc """
  The Locations context.
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo
  alias LocalCafe.Locations.Location

  @doc """
  Returns the list of active locations.
  """
  def list_active_locations do
    Location
    |> where([l], l.active == true)
    |> order_by([l], asc: l.name)
    |> Repo.all()
  end

  @doc """
  Returns the list of all locations (for admin).
  """
  def list_locations do
    Location
    |> order_by([l], asc: l.name)
    |> Repo.all()
  end

  @doc """
  Gets a single location.

  Raises `Ecto.NoResultsError` if the Location does not exist.
  """
  def get_location!(id), do: Repo.get!(Location, id)

  @doc """
  Gets a location by slug.
  """
  def get_location_by_slug!(slug) do
    Repo.get_by!(Location, slug: slug)
  end

  @doc """
  Creates a location.
  """
  def create_location(attrs \\ %{}) do
    %Location{}
    |> Location.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a location.
  """
  def update_location(%Location{} = location, attrs) do
    location
    |> Location.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a location.
  """
  def delete_location(%Location{} = location) do
    Repo.delete(location)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking location changes.
  """
  def change_location(%Location{} = location, attrs \\ %{}) do
    Location.changeset(location, attrs)
  end
end
