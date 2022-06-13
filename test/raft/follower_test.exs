defmodule Raft.FollowerTest do
  use ExUnit.Case, async: true
  @moduletag timeout: :infinity

  describe "follower tests" do
    test "returns a vote for the requester" do
      leader = self()
      this_server = node()

      initial_state = %Raft.ServerState{
        this_server: this_server,
        other_servers: [leader]
      }

      assert({:ok, pid} = Raft.Server.start_link(this_server, [leader], initial_state))

      {:follower, state} = :sys.get_state(pid)

      request = %Raft.RequestVote{
        term: 3,
        candidates_name: leader,
        candidates_last_term: 2,
        candidates_last_index_applied: 2
      }

      GenStateMachine.cast(pid, request)

      assert({:follower, %{voted_for: leader} = %Raft.ServerState{}} = :sys.get_state(pid))
    end

    test "returns a vote against the requester" do
      leader = self()
      this_server = node()

      initial_state = %Raft.ServerState{
        this_server: this_server,
        other_servers: [leader]
      }

      assert({:ok, pid} = Raft.Server.start_link(this_server, [leader], initial_state))

      {:follower, state} = :sys.get_state(pid)

      request = %Raft.RequestVote{}

      GenStateMachine.cast(pid, request)

      assert({:follower, %{voted_for: nil} = %Raft.ServerState{}} = :sys.get_state(pid))
    end
  end
end
