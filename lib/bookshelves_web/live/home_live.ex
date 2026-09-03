defmodule BookshelvesWeb.HomeLive do
  alias BookshelvesWeb.Services.GoogleBooksApi
  alias Bookshelves.Reading
  alias Bookshelves.Repo

  import Ecto.Query

  use BookshelvesWeb, :live_view

  @search_page_size 5
  @search_max 40

  @impl true
  def mount(params, _session, socket) do
    page = list_readings(params)

    {:ok,
      socket
      |> assign(
        page_title: "My bookcase",
        result: [],
        query: "",
        search_limit: @search_page_size,
        can_load_more: false,
        status_filter: "all",
        media_filter: "book",
        title_filter: nil,
        readings: page.entries,
        filtered_readings: page.entries,
        show_modal: false,
        selected_book: nil,
        modal_mode: :edit,
        draft_status: nil,
        draft_page: 0,
        draft_progress: 0,
        draft_tag: "book",
        page_number: page.page_number,
        page_size: page.page_size,
        total_pages: page.total_pages,
        total_entries: page.total_entries
      )
      |> refresh_filtered()
    }
  end

  @impl true
  def handle_event("search", %{"title" => title}, socket) do
    title = String.trim(title)

    if title == "" do
      {:noreply, assign(socket, result: [], query: "", can_load_more: false)}
    else
      result = fetch_results(title, @search_page_size)

      {:noreply,
       assign(socket,
         result: result,
         query: title,
         search_limit: @search_page_size,
         can_load_more: can_load_more?(result, @search_page_size)
       )}
    end
  end

  def handle_event("load_more", _, socket) do
    query = socket.assigns.query
    next_limit = min(socket.assigns.search_limit + @search_page_size, @search_max)

    if query == "" or next_limit == socket.assigns.search_limit do
      {:noreply, assign(socket, can_load_more: false)}
    else
      result = fetch_results(query, next_limit)

      {:noreply,
       assign(socket,
         result: result,
         search_limit: next_limit,
         can_load_more: can_load_more?(result, next_limit)
       )}
    end
  end

  def handle_event("filter_title", %{"title" => title}, socket) do
    {:noreply,
      push_patch(
        socket,
        to:
        ~p"/?page=1&status=#{socket.assigns.status_filter}&media=#{socket.assigns.media_filter}&title=#{title}"
      )}
  end


  def handle_event("filter_status", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         ~p"/?page=1&status=#{filter}&media=#{socket.assigns.media_filter}"
     )}
  end

  def handle_event("filter_media", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         ~p"/?page=1&status=#{socket.assigns.status_filter}&media=#{filter}"
     )}
  end

  def handle_event("select_book", %{"id" => id}, socket) do
    case find_in_results(socket.assigns.result, id) || find_reading(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Title not found")}

      %{status: status} = book when not is_nil(status) ->
        {:noreply, open_edit_modal(socket, book)}

      book ->
        {:noreply,
         assign(socket,
           selected_book: book,
           show_modal: true,
           modal_mode: :add,
           draft_tag: "book"
         )}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_event("validate_add", %{"tags" => tags}, socket) do
    tag = if tags in ["book", "manga"], do: tags, else: "book"
    {:noreply, assign(socket, draft_tag: tag)}
  end

  def handle_event("save_book", params, socket) do
    book = socket.assigns.selected_book
    tags = Map.get(params, "tags") || socket.assigns.draft_tag
    tags = if tags in ["book", "manga"], do: tags, else: "book"

    attrs = %{
      title: book.title,
      authors: book.authors |> List.wrap() |> Enum.join(", "),
      thumbnail: book.thumbnail,
      total_pages: book.total_pages || 0,
      current_page: 0,
      status: :want_read,
      description: book.description,
      published_at: book.published_at,
      tags: tags
    }

    case Repo.insert(Reading.changeset(%Reading{}, attrs)) do
      {:ok, _reading} ->
        readings = list_readings(params)

        {:noreply,
         socket
         |> assign(result: [], query: "", can_load_more: false, readings: readings)
         |> refresh_filtered()
         |> close_modal()
         |> put_flash(:info, "Added to Bookcase")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save the title")}
    end
  end

  def handle_event("validate_reading", %{"reading" => params}, socket) do
    book = socket.assigns.selected_book
    {status, page, progress} = draft_from_params(book, params)

    {:noreply,
     assign(socket,
       draft_status: status,
       draft_page: page,
       draft_progress: progress
     )}
  end

  def handle_event("save_reading", %{"reading" => params}, socket) do
    book = socket.assigns.selected_book
    {status, page, _progress} = draft_from_params(book, params)

    attrs = %{status: status, current_page: page}

    attrs =
      if status == :read and (book.total_pages || 0) > 0 do
        Map.put(attrs, :current_page, book.total_pages)
      else
        attrs
      end

    case update_reading(book.id, attrs) do
      {:ok, _} ->
        readings = list_readings(params)

        {:noreply,
         socket
         |> assign(readings: readings)
         |> refresh_filtered()
         |> close_modal()
         |> put_flash(:info, "Leitura atualizada")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Coudl not updated the title")}
    end
  end

  def handle_event("delete_reading", params, socket) do
    book = socket.assigns.selected_book

    case book && Repo.get(Reading, book.id) do
      nil ->
        {:noreply,
         socket
         |> close_modal()
         |> put_flash(:error, "Title not found")}

      reading ->
        case Repo.delete(reading) do
          {:ok, _} ->
            readings = list_readings(params)

            {:noreply,
             socket
             |> assign(readings: readings)
             |> refresh_filtered()
             |> close_modal()
             |> put_flash(:info, "Leitura excluída")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not drop the title")}
        end
    end
  end

  defp fetch_results(title, limit) do
    case GoogleBooksApi.call(title, limit) do
      {:error, _} -> []
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp can_load_more?(results, limit) do
    length(results) >= limit and limit < @search_max
  end

  defp open_edit_modal(socket, book) do
    page = book.current_page || 0

    assign(socket,
      selected_book: book,
      show_modal: true,
      modal_mode: :edit,
      draft_status: book.status,
      draft_page: page,
      draft_progress: Reading.progress(%{book | current_page: page})
    )
  end

  defp close_modal(socket) do
    assign(socket,
      show_modal: false,
      selected_book: nil,
      modal_mode: :edit,
      draft_status: nil,
      draft_page: 0,
      draft_progress: 0,
      draft_tag: "book"
    )
  end

  defp draft_from_params(book, params) do
    status =
      case Map.get(params, "status") do
        "reading" -> :reading
        "want_read" -> :want_read
        "read" -> :read
        "droped" -> :droped
        _ -> book.status
      end

    page =
      params
      |> Map.get("current_page", "0")
      |> parse_page()
      |> clamp_page(book.total_pages || 0)

    page =
      if status == :read and (book.total_pages || 0) > 0 do
        book.total_pages
      else
        page
      end

    progress = Reading.progress(%{total_pages: book.total_pages, current_page: page})
    {status, page, progress}
  end

  defp parse_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_page(value) when is_integer(value), do: value
  defp parse_page(_), do: 0

  defp clamp_page(page, total) when total > 0, do: page |> max(0) |> min(total)
  defp clamp_page(page, _total), do: max(page, 0)

  defp list_readings(params, status_filter \\ "all", media_filter \\ "book", title \\ nil) do
    Reading
    |> filter_title(title)
    |> filter_status(status_filter)
    |> filter_media(media_filter)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.paginate(params)
  end

  defp refresh_filtered(socket) do
    filtered = socket.assigns.readings

    assign(socket, filtered_readings: filtered)
  end

  defp filter_title(query, nil), do: query
  defp filter_title(query, title) do
    where(query, [r], like(r.title, ^"%#{title}%"))
  end

  defp filter_status(query, "all"), do: query
  defp filter_status(query, status) do 
    where(query, [r], r.status == ^String.to_existing_atom(status))
  end

  defp filter_media(query, "all"), do: query
  defp filter_media(query, "book") do
    where(query, [r], r.tags == "book")
  end
  defp filter_media(query, "manga") do
    where(query, [r], r.tags == "manga")
  end

  defp find_in_results(results, id) do
    Enum.find(results, &(to_string(&1.id) == id))
  end

  defp find_reading(id) do
    Repo.get(Reading, id)
  end

  defp update_reading(id, attrs) do
    id
    |> then(&Repo.get(Reading, &1))
    |> Reading.changeset(attrs)
    |> Repo.update()
  end

  def handle_event("nav", %{"page" => page}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         ~p"/?page=#{page}&status=#{socket.assigns.status_filter}&media=#{socket.assigns.media_filter}"
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = Map.get(params, "page", "1")
    status_filter = Map.get(params, "status", "all")
    media_filter = Map.get(params, "media", "book")
    title = Map.get(params, "title", nil)

    page_data =
      list_readings(
        [page: page],
        status_filter,
        media_filter, 
        title
      )

    {:noreply,
     assign(socket,
       title_filter: title,
       status_filter: status_filter,
       media_filter: media_filter,
       readings: page_data.entries,
       page_number: page_data.page_number,
       page_size: page_data.page_size,
       total_pages: page_data.total_pages,
       total_entries: page_data.total_entries
     )}
  end
end
