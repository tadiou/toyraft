defmodule Raft.CandidateTest do
  use ExUnit.Case, async: true
  @moduletag timeout: :infinity

  describe "Voting tests" do
    test "Successfully runs an election that results in a leader and a follower" do
      other_server = :othernode@nohost
      this_server = :thisnode@nohost

      other_server_initial_state = %Raft.ServerState{
        this_server: other_server,
        other_servers: [this_server]
      }

      initial_state = %Raft.ServerState{
        this_server: this_server,
        other_servers: [other_server]
      }

      {:ok, this_server_pid} =
        Raft.Server.start_link(this_server, [{other_server, node()}], initial_state)

      Process.sleep(20)

      {:ok, other_server_pid} =
        Raft.Server.start_link(other_server, [{this_server, node()}], initial_state)

      GenStateMachine.cast(this_server_pid, :start)
      Process.sleep(20)
      GenStateMachine.cast(other_server_pid, :start)

      resp = :sys.get_state(this_server_pid)
      require IEx
      IEx.pry()
    end
  end
end
