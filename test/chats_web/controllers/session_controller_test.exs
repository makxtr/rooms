defmodule ChatsWeb.SessionControllerTest do
  use ChatsWeb.ConnCase

  describe "GET /api/sessions/me" do
    test "creates new session for first visit", %{conn: conn} do
      conn = get(conn, ~p"/api/sessions/me")

      assert json_response(conn, 200)
      response = json_response(conn, 200)

      assert is_binary(response["session_id"])
      assert response["user_id"] == nil
      assert response["provider_id"] == nil
      assert response["rand_nickname"] == true
      assert is_binary(response["nickname"])
      assert response["ignores"] == [%{}, %{}]
      assert response["subscriptions"] == []
      assert response["rooms"] == []
      assert response["recent_rooms"] == []
      assert is_binary(response["created_at"])
    end

    test "returns existing session on subsequent visits", %{conn: conn} do
      # First request creates session
      conn = get(conn, ~p"/api/sessions/me")
      first_response = json_response(conn, 200)

      # Second request with same conn should return same session
      conn = get(conn, ~p"/api/sessions/me")
      second_response = json_response(conn, 200)

      assert first_response["session_id"] == second_response["session_id"]
      assert first_response["nickname"] == second_response["nickname"]
    end
  end

  describe "PATCH /api/sessions/me" do
    setup %{conn: conn} do
      # Create initial session
      conn = get(conn, ~p"/api/sessions/me")
      %{conn: conn}
    end

    test "updates allowed fields", %{conn: conn} do
      update_params = %{
        "nickname" => "NewNickname",
        "ignores" => [%{"user1" => true}, %{}],
        "subscriptions" => ["room1", "room2"]
      }

      conn = patch(conn, ~p"/api/sessions/me", update_params)

      assert json_response(conn, 200) == %{
               "status" => "ok",
               "updated" => update_params
             }

      # Verify session was actually updated
      conn = get(conn, ~p"/api/sessions/me")
      response = json_response(conn, 200)

      assert response["nickname"] == "NewNickname"
      assert response["ignores"] == [%{"user1" => true}, %{}]
      assert response["subscriptions"] == ["room1", "room2"]
    end

    test "ignores non-allowed fields", %{conn: conn} do
      malicious_params = %{
        "nickname" => "NewNickname",
        "session_id" => "hacker_id",
        "user_id" => "hacker_user"
      }

      conn = patch(conn, ~p"/api/sessions/me", malicious_params)

      # Check session wasn't compromised
      conn = get(conn, ~p"/api/sessions/me")
      response = json_response(conn, 200)

      assert response["nickname"] == "NewNickname"
      assert response["session_id"] != "hacker_id"
      assert response["user_id"] == nil
    end

    test "handles partial updates", %{conn: conn} do
      # Update only nickname
      conn = patch(conn, ~p"/api/sessions/me", %{"nickname" => "OnlyNickname"})

      conn = get(conn, ~p"/api/sessions/me")
      response = json_response(conn, 200)

      assert response["nickname"] == "OnlyNickname"
      # Other fields should remain unchanged
      assert response["ignores"] == [%{}, %{}]
      assert response["subscriptions"] == []
    end
  end
end
