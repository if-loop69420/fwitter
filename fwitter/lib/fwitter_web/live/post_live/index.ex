defmodule FwitterWeb.PostLive.Index do
  use FwitterWeb, :live_view

  alias Fwitter.Dashboard
  alias Fwitter.Dashboard.Post

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :posts, list_posts())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, Dashboard.get_post!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, %Post{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Posts")
    |> assign(:post, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Dashboard.get_post!(id)
    {:ok, _} = Dashboard.delete_post(post)

    {:noreply, assign(socket, :posts, list_posts())}
  end

  defp list_posts do
    Dashboard.list_posts()
  end
end
