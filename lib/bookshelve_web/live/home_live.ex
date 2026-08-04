defmodule BookshelveWeb.HomeLive do
  require IEx
  alias BookshelveWeb.Services.GoogleBooksApi
  alias Bookshelve.Reading
  alias Bookshelve.Repo

  use BookshelveWeb, :live_view

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
  def handle_event("search", %{"title" => title}, socket) do
    result = GoogleBooksApi.call(title)

    {:noreply, assign(socket, result: result)}
  end

  @impl true
  def handle_event("select_book", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.result, &(to_string(&1.id) == id)) do
      nil ->
        case Enum.find(Repo.all(Reading), &(to_string(&1.id) == id)) do 
          nil ->
            {:noreply, put_flash(socket, :error, "Book not found")}
          book ->
            IO.inspect(book.status|>Atom.to_string())
            {:noreply, assign(socket, selected_book: book, show_modal: true)}
        end

      book ->
        {:noreply, assign(socket, selected_book: book, show_modal: true)}
    end
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  @impl true
  def handle_event("close_modal_progress", _, socket) do
    {:noreply, assign(socket, show_modal_progress: false)}
  end

  @impl true
  def handle_event("save_book", _, socket) do
    book = socket.assigns.selected_book

    changeset =
      Reading.changeset(%Reading{}, %{
        title: book.title,
        authors: List.wrap(book.authors) |> Enum.join(", "),
        thumbnail: book.thumbnail,
        current_page: 0,
        total_pages: book.total_pages,
        status: :want_read, 
        description: book.description
      })

    case Repo.insert(changeset) do
      {:ok, _reading} ->
        {:noreply,
          socket
          |> assign(
           result: [],
           readings: Repo.all(Reading),
           show_modal: false,
           selected_book: nil
         )
        |> put_flash(:info, "Book added success")
      }

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save reading")}
    end
  end

  @impl true
  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    reading = Repo.get(Reading, id)
    changeset = Reading.changeset(reading, %{status: status}) 

    case Repo.update(changeset) do
      {:ok, _reading} -> 
        {:noreply, socket
          |> assign(readings: Repo.all(Reading))
          |> put_flash(:info, "status reading updated")
        }
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not updated reading")}
    end
  end

  @impl true
  def handle_event("update_progress", %{"progress" => progress}, socket) do
    reading = Repo.get(Reading, socket.assigns.selected_book.id) 
    changeset = Reading.changeset(reading, %{current_page: progress |> String.to_integer()}) 

    case Repo.update(changeset) do
      {:ok, _reading} -> 
        {:noreply, socket
          |> assign(readings: Repo.all(Reading), show_modal_progress: false)
          |> put_flash(:info, "Updated current page")
        }
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not updated reading")}
    end
  end

  @impl true
  def handle_event("open_modal_progress", %{"id" => id}, socket) do 
    case Enum.find(Repo.all(Reading), &(to_string(&1.id) == id)) do
      nil ->
            {:noreply, put_flash(socket, :error, "Book not found")}
      book ->
        {:noreply, assign(socket, selected_book: book, show_modal_progress: true)}
    end
  end
end
