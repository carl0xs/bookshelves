defmodule BookshelvesWeb.Services.GoogleBooksApi do
  def call(title, maxResults \\ 5) do
    case Req.get(
           "https://www.googleapis.com/books/v1/volumes",
           params: [
             q: title,
             maxResults: maxResults,
             key: Application.get_env(:bookshelves, :google_books)[:api_key]
           ]
         ) do
      {:ok, %{body: body}} ->
        parse_result(body["items"])

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_result(items) do
    Enum.map(items || [], fn item ->
      %{
        id: item["id"],
        title: get_in(item, ["volumeInfo", "title"]),
        authors: get_in(item, ["volumeInfo", "authors"]) || [],
        description: get_in(item, ["volumeInfo", "description"]),
        thumbnail: get_in(item, ["volumeInfo", "imageLinks", "thumbnail"]),
        published_at: get_in(item, ["volumeInfo", "publishedDate"]),
        total_pages: get_in(item, ["volumeInfo", "pageCount"])
      }
    end)
  end
end
