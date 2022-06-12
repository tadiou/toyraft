defmodule Raft.Server do
  @moduledoc """
  The server which implements raft on a given server.

  I'd prefer the 'node' nomenclature, but `node/0` is already use by Kernel.
  """

  require Logger

  use GenStateMachine, callback_mode: :state_functions

  @type state :: :leader | :follower | :candidate

  # When we start, we're going to need information about the random timeout for this server
  @spec start_link(atom | {:global, any} | {:via, atom, any}, list, list) ::
          :ignore | {:error, any} | {:ok, pid}
  def start_link(this_server, other_servers, opts \\ []) do
    Logger.info("Floating raft: #{inspect(this_server)}")

    GenStateMachine.start_link(__MODULE__, [this_server, other_servers, opts], name: this_server)
  end

  def init([this_server, other_servers]) do
    # add the server to the supervisor holding the servers info

    # Put it in follower mode, and when it doesn't get a response after timeout,
    # it'll start an election
    {:ok, :follower,
     %Raft.ServerState{
       this_server: {this_server, node()},
       other_servers: other_servers
     }}
  end

  @spec follower(:cast, any, any) ::
          {:keep_state_and_data, [{{any, any}, integer, :begin_election}]}
          | {:keep_state, Raft.ServerState.t(), [{:next_event, :cast, any}, ...]}
  def follower(:cast, :start, server_state) do
    Logger.info("#{inspect(server_state.this_server)} timeout started")

    {:keep_state_and_data,
     [{{:timeout, :election_timeout}, Raft.GenTimeout.call(), :begin_election}]}
  end

  def follower(:cast, :data, data) do
    IO.inspect(data, label: "Data")
    {:keep_state_and_data, []}
  end

  # Writes as the follower
  def follower(
        :cast,
        write,
        state = %Raft.ServerState{
          last_index_applied: last_index_applied,
          leader_index: leader_index
        }
      )
      when leader_index > last_index_applied do
    # write to log

    {:keep_state,
     %Raft.ServerState{
       state
       | last_index_applied: last_index_applied + 1
     }, [{:next_event, :cast, write}]}
  end

  # Should just probably add a guard clause to return false
  @spec request_vote(any, any, any, any) :: {:ok, boolean}
  def request_vote(term, _, _, _) when 0 > term do
    {:ok, false}
  end

  def request_vote(term, candidate_id, last_log_index, last_log_term) do
    {:ok, true}
  end
end
