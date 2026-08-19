defmodule BookshelvesWeb.HomeLive do
  alias BookshelvesWeb.Services.GoogleBooksApi
  alias Bookshelves.Reading
  alias Bookshelves.Repo

  use BookshelvesWeb, :live_view

  alias BookshelvesWeb.BookComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       result: [],
       readings: Repo.all(Reading),
       show_modal: false,
       show_modal_progress: false,
       selected_book: nil
     )}
  end

  @impl true
  def handle_event("search", %{"title" => title, "max_results" => max_results}, socket) do
    result = GoogleBooksApi.call(title, max_results || 5)
    {:noreply, assign(socket, result: result)}
  end

  def handle_event("select_book", %{"id" => id}, socket) do
    book = find_in_results(socket.assigns.result, id) || find_reading(id)

    case book do
      nil -> {:noreply, put_flash(socket, :error, "Book not found")}
      book -> {:noreply, assign(socket, selected_book: book, show_modal: true)}
    end
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  def handle_event("close_modal_progress", _, socket) do
    {:noreply, assign(socket, show_modal_progress: false)}
  end

  def handle_event("save_book", _, socket) do
    book = socket.assigns.selected_book

    attrs = %{
      title: book.title,
      authors: book.authors |> List.wrap() |> Enum.join(", "),
      thumbnail: book.thumbnail,
      total_pages: book.total_pages,
      status: :want_read,
      description: book.description,
      published_at: book.published_at
    }

    case Repo.insert(Reading.changeset(%Reading{}, attrs)) do
      {:ok, _reading} ->
        {:noreply,
         socket
         |> assign(result: [], readings: Repo.all(Reading), show_modal: false, selected_book: nil)
         |> put_flash(:info, "Book added successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save reading")}
    end
  end

  def handle_event("update_status", %{"status" => status}, socket) do
    socket.assigns.selected_book.id
    |> update_reading(%{status: status})
    |> handle_update_result(socket, "Status updated")
  end

  def handle_event("update_progress", %{"progress" => progress}, socket) do
    socket.assigns.selected_book.id
    |> update_reading(%{current_page: String.to_integer(progress)})
    |> handle_update_result(
      assign(socket, show_modal_progress: false),
      "Progress updated"
    )
  end

  def handle_event("open_modal_progress", %{"id" => id}, socket) do
    case find_reading(id) do
      nil -> {:noreply, put_flash(socket, :error, "Book not found")}
      book -> {:noreply, assign(socket, selected_book: book, show_modal_progress: true)}
    end
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

  defp handle_update_result({:ok, _}, socket, message) do
    {:noreply,
     socket
     |> assign(readings: Repo.all(Reading))
     |> put_flash(:info, message)}
  end

  defp handle_update_result({:error, _}, socket, _message) do
    {:noreply, put_flash(socket, :error, "Could not update reading")}
  end
end
