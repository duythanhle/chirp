defmodule ChirpWeb.PostLive.FormComponent do
  use ChirpWeb, :live_component

  alias Chirp.Timeline
  alias Chirp.Timeline.Post
  require Logger

  @impl true
  def mount(socket) do
    {:ok,
    socket
    |> allow_upload(:photo, accept: ~w(.jpg .jpeg .png), max_entries: 2)}
    # {:ok, allow_upload(socket, :photo, accept: ~w(.png .jpeg .jpg), max_entries: 2)}
  end

  @impl true
  def update(%{post: post} = assigns, socket) do
    changeset = Timeline.change_post(post)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.post
      |> Timeline.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.action, post_params)
  end

  def handle_event("cancel-entry", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  defp save_post(socket, :edit, post_params) do
    uploaded_files =
      consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
        dest = Path.join([:code.priv_dir(:chirp), "static", "uploads", Path.basename(path)])
        # The `static/uploads` directory must exist for `File.cp!/2` to work.
        File.cp!(path, dest)

        {:ok, Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")}
      end)
    # post = put_photo_urls(socket, %Post{})
    case Timeline.update_post(%Post{socket.assigns.post | photo_urls: uploaded_files}, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_post(socket, :new, post_params) do
    uploaded_files =
      consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
        dest = Path.join([:code.priv_dir(:chirp), "static", "uploads", Path.basename(path)])
        # The `static/uploads` directory must exist for `File.cp!/2` to work.
        File.cp!(path, dest)

        {:ok, Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")}
      end)

    # post = put_photo_urls(socket, %Post{})
    case Timeline.create_post(%Post{photo_urls: uploaded_files}, post_params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post created successfully")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  # defp put_photo_urls(socket, %Post{} = post) do
  #   {completed, []} = uploaded_entries(socket, :photo)
  #   urls =
  #     for entry <- completed do
  #       Routes.static_path(socket, "/uploads/#{entry.uuid}.#{ext(entry)}")
  #     end
  #   %Post{post | photo_urls: urls}
  # end

  def consume_photos(socket, %Post{} = post) do
    consume_uploaded_entries(socket, :photo, fn %{path: path}, entry ->
      dest = Path.join([:code.priv_dir(:chirp), "static/uploads", "#{entry.uuid}.#{ext(entry)}"])
      File.cp!(path, dest)
    end)
    {:ok, post}
  end

end
