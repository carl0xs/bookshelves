defmodule BookshelvesWeb.BookComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import BookshelvesWeb.CoreComponents

  alias Bookshelves.Reading

  attr :result, :list, default: []

  def search_form(assigns) do
    ~H"""
    <div class="mx-auto max-w-xl lg:mx-0 mb-3">
      <.form for={%{}} phx-submit="search" class="flex gap-5">
        <input
          class="w-xl h-10 rounded-md p-4 border bg-white text-black"
          placeholder="search book"
          name="title"
        />
        <input type="hidden" value={5} name="max_results" />
      </.form>
    </div>
    """
  end

  attr :results, :list, required: true

  def search_results(assigns) do
    ~H"""
    <div :if={@results != []} class="searching-container">
      <ul>
        <li
          :for={result <- @results}
          class="flex gap-2 cursor-pointer"
          phx-click="select_book"
          phx-value-id={result.id}
        >
          <img class="reading-search-img mb-3" src={result.thumbnail} alt={result.title} />
          <div>
            <span class="text-[11px] block">{result.title}</span>
            <span class="text-[11px] block">by {result.authors}</span>
            <span class="text-[11px] block">published at: {result.published_at}</span>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  attr :book, :map, required: true
  attr :show, :boolean, default: false

  def book_detail_modal(assigns) do
    ~H"""
    <.modal id="book-detail-modal" show={@show} on_cancel={JS.push("close_modal")}>
      <div class="flex space-y-4 gap-2">
        <img src={@book.thumbnail} class="w-32" alt={@book.title} />
        <div>
          <span class="text-black block">{@book.title}</span>
          <span class="text-black block">by {@book.authors}</span>
          <span class="text-black block text-[10px]">{@book.description}</span>
        </div>

        <%= if Map.get(@book, :status) do %>
          <.form for={%{}} phx-change="update_status">
            <select name="status">
              <option value="want_read" selected={@book.status == :want_read}>Want Read</option>
              <option value="reading" selected={@book.status == :reading}>Reading</option>
              <option value="droped" selected={@book.status == :droped}>Dropped</option>
              <option value="read" selected={@book.status == :read}>Read</option>
            </select>
          </.form>
        <% end %>
      </div>

      <div :if={!Map.get(@book, :status)}>
        <button phx-click="save_book" class="rounded bg-blue-600 px-4 py-2 text-white">
          Add to Bookshelves
        </button>
      </div>
    </.modal>
    """
  end

  attr :book, :map, required: true
  attr :show, :boolean, default: false

  def progress_modal(assigns) do
    ~H"""
    <.modal
      id="progress-modal"
      show={@show}
      on_cancel={JS.push("close_modal_progress")}
      class="w-[250px]"
    >
      <div class="flex space-y-4 gap-2">
        <div>
          <span class="text-black block">{@book.title}</span>
          <.form for={%{}} phx-submit="update_progress">
            <input class="bg-white text-black" type="number" name="progress" min="0" max={@book.total_pages} />
            <span>/ {@book.total_pages}</span>
            <button class="flex pt-3" type="submit">Salvar</button>
          </.form>
        </div>
      </div>
    </.modal>
    """
  end

  attr :reading, :map, required: true

  def book_card(assigns) do
    assigns = assign(assigns, :progress, Reading.progress(assigns.reading))

    ~H"""
    <div>
      <div class="image-container">
        <img
          class="reading-img"
          src={@reading.thumbnail || "http://books.google.com/books/content?id=tOlNAQAAIAAJ&printsec=frontcover&img=1&zoom=1&source=gbs_api"}
          title={@reading.title}
          phx-click="select_book"
          phx-value-id={@reading.id}
        />
        <button class="btn-update-status" phx-click="open_modal_progress" phx-value-id={@reading.id}>
          <.icon name="hero-bars-3" />
        </button>
        <span class="badge">{@reading.status}</span>
      </div>
      <div class="w-[200px]">
        <span class="w-[140px] block text-[10px] truncate">{@reading.title}</span>
        <span class="text-[12px]">{@reading.current_page} / {@reading.total_pages} ({@progress}%)</span>
      </div>
    </div>
    """
  end
end
