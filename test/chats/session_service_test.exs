defmodule Chats.SessionServiceTest do
  use ExUnit.Case, async: true
  alias Chats.SessionService

  describe "create_initial_session/0" do
    test "creates session with required fields" do
      session = SessionService.create_initial_session()

      assert is_binary(session.session_id)
      assert session.user_id == nil
      assert session.provider_id == nil
      assert session.rand_nickname == true
      assert is_binary(session.nickname)
      assert session.ignores == [%{}, %{}]
      assert session.subscriptions == []
      assert session.rooms == []
      assert session.recent_rooms == []
      assert is_binary(session.created_at)
    end

    test "generates unique session IDs" do
      session1 = SessionService.create_initial_session()
      session2 = SessionService.create_initial_session()

      assert session1.session_id != session2.session_id
    end
  end

  describe "generate_session_id/0" do
    test "generates base64 encoded string" do
      session_id = SessionService.generate_session_id()

      assert is_binary(session_id)
      assert String.length(session_id) > 0
      # Base64 without padding should not contain '='
      refute String.contains?(session_id, "=")
    end
  end

  describe "generate_random_nickname/0" do
    test "generates nickname with adjective, noun and number" do
      nickname = SessionService.generate_random_nickname()

      assert is_binary(nickname)
      assert String.length(nickname) > 0
      # Should contain at least one digit at the end
      assert Regex.match?(~r/\d+$/, nickname)
    end
  end

  describe "update_session_fields/2" do
    setup do
      initial_session = %{
        session_id: "test_id",
        nickname: "OldName",
        ignores: [%{}, %{}],
        subscriptions: []
      }

      %{session: initial_session}
    end

    test "updates allowed fields", %{session: session} do
      params = %{
        "nickname" => "NewName",
        "ignores" => [%{"user1" => true}, %{}],
        "subscriptions" => ["room1"]
      }

      updated_session = SessionService.update_session_fields(session, params)

      assert updated_session.nickname == "NewName"
      assert updated_session.ignores == [%{"user1" => true}, %{}]
      assert updated_session.subscriptions == ["room1"]
    end

    test "ignores non-allowed fields", %{session: session} do
      params = %{
        "nickname" => "NewName",
        "session_id" => "hacker_id",
        "user_id" => "hacker_user"
      }

      updated_session = SessionService.update_session_fields(session, params)

      assert updated_session.nickname == "NewName"
      # unchanged
      assert updated_session.session_id == "test_id"
    end

    test "ignores nil values", %{session: session} do
      params = %{
        "nickname" => nil,
        "ignores" => [%{"user1" => true}, %{}]
      }

      updated_session = SessionService.update_session_fields(session, params)

      # unchanged
      assert updated_session.nickname == "OldName"
      assert updated_session.ignores == [%{"user1" => true}, %{}]
    end
  end
end
