defmodule Bookshelve.Repo do
  use Ecto.Repo,
    otp_app: :bookshelve,
    adapter: Ecto.Adapters.SQLite3
end
