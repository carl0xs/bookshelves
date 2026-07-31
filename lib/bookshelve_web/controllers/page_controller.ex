defmodule BookshelveWeb.PageController do
  use BookshelveWeb, :controller

  def home(conn, _params) do
    IO.inspect("")
    render(conn, :home)
  end
end
