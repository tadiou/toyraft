defmodule Raft.ServerTest do
  use ExUnit.Case, async: true

  describe "init tests" do
    test "starts the server" do
      leader = self()
      this_server = node()

      initial_state = %Raft.ServerState{
        this_server: this_server,
        other_servers: [leader]
      }

      assert({:ok, pid} = Raft.Server.start_link(this_server, [leader], initial_state))
    end
  end
end
