defmodule LocalCafe.Anayltics do
  use Ecto.Schema
  import Ecto.Query
  alias LocalCafe.CH_Repo

  @primary_key false
  schema "analytics" do
    field :path, Ch, type: "String"
    field :agent, Ch, type: "String"
    field :ip, Ch, type: "String"
    field :referer, Ch, type: "String"
    field :session_id, Ch, type: "String"
    field :inserted_at, Ch, type: "DateTime"
    field :country, Ch, type: "String"
    field :browser, Ch, type: "String"
    field :os, Ch, type: "String"
    field :device, Ch, type: "String"
    field :bot, Ch, type: "String"
  end

  def page_views(start_date, end_date) do
    from(a in __MODULE__,
      select: %{
        date: fragment("toDate(?)", a.inserted_at),
        path: a.path,
        page_views: count(),
        unique_visitors: fragment("uniq(?)", a.session_id)
      },
      where: a.inserted_at >= ^start_date and a.inserted_at < ^end_date,
      group_by: [fragment("toDate(?)", a.inserted_at), a.path],
      order_by: [fragment("toDate(?)", a.inserted_at), desc: count()]
    )
    |> CH_Repo.all()
  end

  def top_pages() do
    from(a in __MODULE__,
      select: %{
        path: a.path,
        page_views: count()
      },
      group_by: a.path,
      order_by: [desc: count()],
      limit: 20
    )
    |> CH_Repo.all()
  end

  def traffic_source() do
    from(a in __MODULE__,
      select: %{
        referer: a.referer,
        visits: count()
      },
      where: a.referer != "",
      group_by: a.referer,
      order_by: [desc: count()],
      limit: 20
    )
    |> CH_Repo.all()
  end

  def geographic() do
    from(a in __MODULE__,
      select: %{
        country: a.country,
        visits: count(),
        unique_visitors: fragment("uniq(?)", a.session_id)
      },
      where: a.country != "",
      group_by: a.country,
      order_by: [desc: count()]
    )
    |> CH_Repo.all()
  end

  def hourly() do
    from(a in __MODULE__,
      select: %{
        hour: fragment("toHour(?)", a.inserted_at),
        visits: count()
      },
      group_by: fragment("toHour(?)", a.inserted_at),
      order_by: fragment("toHour(?)", a.inserted_at)
    )
    |> CH_Repo.all()
  end
end
