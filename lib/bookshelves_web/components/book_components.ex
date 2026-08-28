defmodule BookshelvesWeb.BookComponents do
  use Phoenix.Component
  use Gettext, backend: BookshelvesWeb.Gettext

  alias Phoenix.LiveView.JS
  import BookshelvesWeb.CoreComponents

  alias Bookshelves.Reading

  @filters [
    {"all",       "All"       },
    {"reading",   "Reading"   },
    {"want_read", "Want_read" },
    {"read",      "Read"      },
    {"droped",    "Droped"    }
  ]

  @media_filters [
      {"all",   "All"  },
      {"books", "Books"},
      {"manga", "Manga"}
  ]

  @status_options [
    {"reading",   "Reading",  },
    {"want_read", "Want_read",},
    {"read",      "Read",     },
    {"droped",    "Droped",   }
  ]

  attr :query, :string, default: ""

  def search_form(assigns) do
    ~H"""
    <section id="busca" class="w-full max-w-xl">
      <.form for={%{}} phx-submit="search" id="search-form" class="relative">
        <label for="search-title" class="sr-only">search books</label>
        <.icon
          name="hero-magnifying-glass"
          class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-base-content/50"
        />
        <input
          id="search-title"
          type="search"
          name="title"
          value={@query}
          placeholder="search books…"
          autocomplete="off"
          class="w-full rounded-md border border-white/20 bg-base-100 py-2.5 pl-10 pr-4 text-sm text-base-content placeholder:text-base-content/40 outline-none transition focus:border-white focus:ring-1 focus:ring-white/40"
        />
      </.form>
    </section>
    """
  end

  attr :results, :list, required: true
  attr :can_load_more, :boolean, default: false

  def search_results(assigns) do
    ~H"""
    <div
      :if={@results != []}
      id="search-results"
      class="scroll-thin mx-auto mt-3 max-h-72 w-full max-w-xl overflow-y-auto rounded-md border border-base-300 bg-base-100"
    >
      <ul class="divide-y divide-base-300" role="listbox" aria-label="Resultados da busca">
        <li
          :for={result <- @results}
          id={"search-result-#{result.id}"}
          role="option"
          class="flex cursor-pointer gap-3 px-3 py-2.5 transition-colors hover:bg-base-200"
          phx-click="select_book"
          phx-value-id={result.id}
        >
          <img
            class="h-16 w-11 shrink-0 rounded-sm object-cover cover-shadow"
            src={cover_url(result.thumbnail)}
            alt={"Capa de #{result.title}"}
          />
          <div class="min-w-0 self-center">
            <p class="truncate text-sm font-medium text-base-content">{result.title}</p>
            <p class="truncate text-xs text-base-content/70">
              {format_authors(result.authors)}
            </p>
            <p :if={result.published_at} class="mt-0.5 text-[0.65rem] text-base-content/50">
              {result.published_at}
            </p>
          </div>
        </li>
      </ul>

      <div :if={@can_load_more} class="border-t border-base-300 p-2">
        <button
          id="search-load-more"
          type="button"
          phx-click="load_more"
          class="w-full rounded-md px-3 py-2 text-sm font-medium text-white transition hover:bg-white/10"
        >
          See more
        </button>
      </div>
    </div>
    """
  end

  attr :status_filter, :string, required: true
  attr :media_filter, :string, required: true
  attr :count, :integer, required: true

  def shelf_filters(assigns) do
    assigns =
      assigns
      |> assign(:filters, @filters)
      |> assign(:media_filters, @media_filters)

    ~H"""
    <div class="mt-6 space-y-3">
      <h2
        id="minha-estante"
        class="text-2xl font-semibold tracking-tight text-base-content sm:text-[1.65rem]"
      >
        Bookcase
      </h2>

      <nav id="shelf-filters" class="filter-bar scroll-thin" aria-label="Filtros por status">
        <button
          :for={{value, label} <- @filters}
          id={"filter-status-#{value}"}
          type="button"
          aria-pressed={to_string(@status_filter == value)}
          phx-click="filter_status"
          phx-value-filter={value}
        >
          {label}
        </button>
      </nav>

      <nav
        id="media-filter"
        class="filter-bar filter-bar-sm scroll-thin"
        aria-label="filter by type"
      >
        <button
          :for={{value, label} <- @media_filters}
          id={"filter-media-#{value}"}
          type="button"
          aria-pressed={to_string(@media_filter == value)}
          phx-click="filter_media"
          phx-value-filter={value}
        >
          {label}
        </button>
      </nav>

      <p class="flex items-center gap-1.5 text-sm text-base-content/70">
        <.icon name="hero-bookmark-square" class="size-4 text-base-content/50" />
        <span>{ngettext("%{count} title", "%{count} titles", @count, count: @count)}</span>
      </p>
    </div>
    """
  end

  attr :readings, :list, required: true

  def shelf_grid(assigns) do
    ~H"""
    <div
      id="shelf-grid"
      class={[
        "mt-6",
        @readings == [] && "py-16 text-center",
        @readings != [] &&
          "grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-3 sm:gap-x-5 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6"
      ]}
    >
      <%= if @readings == [] do %>
        <div class="mx-auto max-w-sm space-y-2">
          <p class="text-lg text-base-content">Estante vazia por aqui</p>
          <p class="text-sm text-base-content/70">
            Use a busca acima para adicionar um livro ou mangá à sua estante.
          </p>
        </div>
      <% else %>
        <.book_card :for={reading <- @readings} reading={reading} />
      <% end %>
    </div>
    """
  end

  attr :reading, :map, required: true

  def book_card(assigns) do
    progress = Reading.progress(assigns.reading)
    media = Reading.media_type(assigns.reading)

    assigns =
      assigns
      |> assign(:progress, progress)
      |> assign(:media_label, media_label(media))
      |> assign(:status_label, Reading.status_label(assigns.reading.status) || "—")

    ~H"""
    <article id={"reading-#{@reading.id}"} class="group flex flex-col gap-2.5">
      <button
        type="button"
        id={"reading-cover-#{@reading.id}"}
        class="cover-shadow cover-shadow-hover relative aspect-[2/3] w-full overflow-hidden rounded-sm bg-base-300 text-left outline-none ring-white/40 focus-visible:ring-2"
        phx-click="select_book"
        phx-value-id={@reading.id}
        aria-label={"Abrir #{@reading.title}"}
      >
        <img
          class="h-full w-full object-cover"
          src={cover_url(@reading.thumbnail)}
          alt=""
          loading="lazy"
        />
        <span
          class="status-tag absolute left-1.5 top-1.5 backdrop-blur-[2px]"
          data-status={@reading.status}
        >
          {@status_label}
        </span>
      </button>

      <div class="min-w-0 space-y-1.5">
        <div>
          <h3
            class="truncate text-sm font-medium leading-snug text-base-content"
            title={@reading.title}
          >
            {@reading.title}
          </h3>
          <p class="truncate text-xs text-base-content/70" title={@reading.authors}>
            {@reading.authors}
          </p>
        </div>

        <div class="flex items-center gap-1.5 text-[0.65rem] text-base-content/50">
          <span class="uppercase tracking-wide">{@media_label}</span>
          <span aria-hidden="true">·</span>
          <span>
            {@reading.current_page || 0}/{@reading.total_pages || 0}
          </span>
        </div>

        <div class="space-y-1">
          <div
            class="progress-track"
            role="progressbar"
            aria-valuemin="0"
            aria-valuemax="100"
            aria-valuenow={@progress}
            aria-label={"Progresso: #{@progress}%"}
          >
            <div class="progress-fill" style={"width: #{@progress}%"} />
          </div>
          <p class="text-[0.65rem] tabular-nums text-base-content/50">{@progress}%</p>
        </div>
      </div>
    </article>
    """
  end

  attr :book, :map, required: true
  attr :show, :boolean, default: false
  attr :mode, :atom, values: [:add, :edit], default: :edit
  attr :draft_status, :atom, default: nil
  attr :draft_page, :integer, default: 0
  attr :draft_progress, :integer, default: 0
  attr :draft_tag, :string, default: "book"

  def book_detail_modal(assigns) do
    ~H"""
    <.modal id="book-detail-modal" show={@show} on_cancel={JS.push("close_modal")}>
      <%= if @mode == :add do %>
        <.add_book_panel book={@book} draft_tag={@draft_tag} />
      <% else %>
        <.edit_reading_panel
          book={@book}
          draft_status={@draft_status}
          draft_page={@draft_page}
          draft_progress={@draft_progress}
        />
      <% end %>
    </.modal>
    """
  end

  attr :book, :map, required: true
  attr :draft_tag, :string, required: true

  defp add_book_panel(assigns) do
    ~H"""
    <div class="flex flex-col gap-5 sm:flex-row sm:gap-6">
      <img
        src={cover_url(@book.thumbnail)}
        alt={"Capa de #{@book.title}"}
        class="mx-auto h-44 w-auto shrink-0 rounded-sm object-cover cover-shadow sm:mx-0 sm:h-52"
      />
      <div class="min-w-0 flex-1 space-y-4">
        <div>
          <h2 id="book-detail-modal-title" class="text-xl font-semibold text-base-content">
            {@book.title}
          </h2>
          <p class="mt-1 text-sm text-base-content/70">{format_authors(@book.authors)}</p>
          <p :if={@book.published_at} class="mt-1 text-xs text-base-content/50">
            Publicado em {@book.published_at}
          </p>
        </div>

        <p
          :if={@book.description}
          class="line-clamp-4 text-sm leading-relaxed text-base-content/70"
        >
          {@book.description}
        </p>

        <.form
          for={%{}}
          id="add-book-form"
          phx-change="validate_add"
          phx-submit="save_book"
          class="space-y-4"
        >
          <fieldset>
            <legend class="mb-2 text-xs font-medium uppercase tracking-wide text-base-content/50">
              Tipo
            </legend>
            <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Tipo da obra">
              <label
                :for={{value, label} <- [{"book", "Livro"}, {"manga", "Mangá"}]}
                class={[
                  "cursor-pointer rounded-md border px-3 py-1.5 text-sm transition",
                  @draft_tag == value && "border-white bg-white text-black",
                  @draft_tag != value &&
                    "border-white/40 text-white hover:bg-white/10"
                ]}
              >
                <input
                  type="radio"
                  name="tags"
                  value={value}
                  checked={@draft_tag == value}
                  class="sr-only"
                />
                {label}
              </label>
            </div>
          </fieldset>

          <div class="flex flex-wrap gap-2 pt-1">
            <button
              id="add-book-btn"
              type="submit"
              class="btn btn-primary"
            >
              Adicionar à estante
            </button>
            <button
              type="button"
              phx-click={JS.exec("data-cancel", to: "#book-detail-modal")}
              class="btn btn-ghost"
            >
              Cancelar
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :book, :map, required: true
  attr :draft_status, :atom, required: true
  attr :draft_page, :integer, required: true
  attr :draft_progress, :integer, required: true

  defp edit_reading_panel(assigns) do
    media = Reading.media_type(assigns.book)

    assigns =
      assigns
      |> assign(:media_label, media_label(media))
      |> assign(:status_options, @status_options)

    ~H"""
    <div class="flex flex-col gap-5 sm:flex-row sm:gap-6">
      <img
        src={cover_url(@book.thumbnail)}
        alt={"Capa de #{@book.title}"}
        class="mx-auto h-44 w-auto shrink-0 rounded-sm object-cover cover-shadow sm:mx-0 sm:h-52"
      />

      <div class="min-w-0 flex-1">
        <div class="mb-5">
          <div class="mb-2 flex flex-wrap items-center gap-2">
            <span class="status-tag" data-status={@draft_status}>
              {Reading.status_label(@draft_status)}
            </span>
            <span class="text-[0.65rem] uppercase tracking-wide text-base-content/50">
              {@media_label}
            </span>
          </div>
          <h2 id="book-detail-modal-title" class="text-xl font-semibold text-base-content">
            {@book.title}
          </h2>
          <p class="mt-1 text-sm text-base-content/70">{@book.authors}</p>
        </div>

        <.form
          for={%{}}
          id="reading-edit-form"
          phx-change="validate_reading"
          phx-submit="save_reading"
          class="space-y-5"
        >
          <fieldset>
            <legend class="mb-2 text-xs font-medium uppercase tracking-wide text-base-content/50">
              Status
            </legend>
            <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Status da leitura">
              <label
                :for={{value, label} <- @status_options}
                class={[
                  "cursor-pointer rounded-md border px-3 py-1.5 text-sm transition",
                  to_string(@draft_status) == value &&
                    "border-white bg-white text-black",
                  to_string(@draft_status) != value &&
                    "border-white/40 text-white hover:bg-white/10"
                ]}
              >
                <input
                  type="radio"
                  name="reading[status]"
                  value={value}
                  checked={to_string(@draft_status) == value}
                  class="sr-only"
                />
                {label}
              </label>
            </div>
          </fieldset>

          <div>
            <label
              for="reading-page"
              class="mb-2 block text-xs font-medium uppercase tracking-wide text-base-content/50"
            >
              Current Page
            </label>
            <div class="flex items-center gap-2">
              <input
                id="reading-page"
                type="number"
                name="reading[current_page]"
                value={@draft_page}
                min="0"
                max={@book.total_pages || 0}
                class="w-24 rounded-md border border-white/20 bg-black px-3 py-2 text-sm tabular-nums text-base-content outline-none transition focus:border-white focus:ring-1 focus:ring-white/40"
              />
              <span class="text-sm text-base-content/70">/ {@book.total_pages || 0}</span>
            </div>
          </div>

          <div class="space-y-2">
            <div class="flex items-baseline justify-between gap-2">
              <span class="text-xs font-medium uppercase tracking-wide text-base-content/50">
                Progress
              </span>
              <span id="draft-progress-label" class="text-sm tabular-nums text-white">
                {@draft_progress}%
              </span>
            </div>
            <div
              class="progress-track"
              style="height: 3px"
              role="progressbar"
              aria-valuemin="0"
              aria-valuemax="100"
              aria-valuenow={@draft_progress}
            >
              <div class="progress-fill" style={"width: #{@draft_progress}%"} />
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2 pt-1">
            <button id="save-reading-btn" type="submit" class="btn btn-primary">
              Save
            </button>
            <button
              id="cancel-reading-btn"
              type="button"
              phx-click={JS.exec("data-cancel", to: "#book-detail-modal")}
              class="btn btn-ghost"
            >
              Cancel
            </button>
            <button
              id="delete-reading-btn"
              type="button"
              phx-click="delete_reading"
              data-confirm="Excluir esta leitura da estante?"
              class="btn btn-ghost btn-sm ml-auto text-error"
            >
              Delete
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp cover_url(nil), do: "/images/placeholder.jpg"
  defp cover_url(""), do: "/images/placeholder.jpg"
  defp cover_url(url), do: url

  defp format_authors(authors) when is_list(authors), do: Enum.join(authors, ", ")
  defp format_authors(authors) when is_binary(authors), do: authors
  defp format_authors(_), do: "Autor desconhecido"

  defp media_label(:manga), do: "Manga"
  defp media_label(_), do: "Book"
end
