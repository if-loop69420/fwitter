defmodule Fwitter.DashboardTest do
  use Fwitter.DataCase

  alias Fwitter.Dashboard

  describe "posts" do
    alias Fwitter.Dashboard.Post

    import Fwitter.DashboardFixtures

    @invalid_attrs %{body: nil, likes: nil}

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Dashboard.list_posts() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Dashboard.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{body: "some body", likes: 42}

      assert {:ok, %Post{} = post} = Dashboard.create_post(valid_attrs)
      assert post.body == "some body"
      assert post.likes == 42
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dashboard.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{body: "some updated body", likes: 43}

      assert {:ok, %Post{} = post} = Dashboard.update_post(post, update_attrs)
      assert post.body == "some updated body"
      assert post.likes == 43
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Dashboard.update_post(post, @invalid_attrs)
      assert post == Dashboard.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Dashboard.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Dashboard.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Dashboard.change_post(post)
    end
  end
end
