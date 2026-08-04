defmodule BookshelveWeb.Repo.Migrations.CreateReadings do
  use Ecto.Migration

  def change do
    create table(:readings) do
      add :title, :string
      add :published_at, :string
      add :authors, :string
      add :current_page, :integer
      add :total_pages, :integer
      add :thumbnail, :string
      add :status, :string
      add :description, :string
      add :tags, :string

      timestamps(type: :utc_datetime)
    end
  end
end
