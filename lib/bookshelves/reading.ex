defmodule Bookshelves.Reading do
  use Ecto.Schema
  import Ecto.Changeset

  schema "readings" do
    field :title, :string
    field :authors, :string
    field :current_page, :integer, default: 0
    field :total_pages, :integer, default: 0
    field :thumbnail, :string
    field :status, Ecto.Enum, values: [want_read: "want_read", read: "read", reading: "reading", droped: "droped"]
    field :description, :string
    field :tags, :string
    field :published_at, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reading, attrs) do
    reading
    |> cast(attrs, [
      :title,
      :authors,
      :description,
      :tags,
      :current_page,
      :total_pages,
      :thumbnail,
      :status,
      :published_at
    ])
    |> validate_required([:title, :authors, :total_pages])
  end

  def progress(reading) do
    Kernel.round((reading.current_page || 0 / reading.total_pages || 0) * 100)
  end
end
