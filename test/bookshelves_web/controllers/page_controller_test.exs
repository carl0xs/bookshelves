defmodule BookshelvesWeb.PageControllerTest do
  use BookshelvesWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Bookshelve"
    assert html_response(conn, 200) =~ "Minha estante"
  end
end
