defmodule Raft.Server do
  @moduledoc """
  The server which implements raft on a given server.

  I'd prefer the 'node' nomenclature, but `node/0` is already use by Kernel.

  For everyone else's notation: cast is async, call is sync.

  :keep_state means we're going to continue to be in the current state, which is :follower,
  :candidate, or :leader.


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

  def init([this_server, other_servers, _opts]) do
    Logger.info("Initializing raft: #{inspect(this_server)}")
    # add the server to the supervisor holding the servers info

    # Put it in follower mode, and when it doesn't get a response after timeout,
    # it'll start an election
    {:ok, :follower,
     %Raft.ServerState{
       this_server: {this_server, node()},
       other_servers: other_servers
     }}
  end

  # Starts the server with an election. If the server is put into service while there's
  # currently other servers around, it'll fail the election as the term < current term.
  def follower(:cast, :start, server_state) do
    Logger.info("#{inspect(server_state.this_server)} timeout started")

    {:keep_state_and_data,
     [{{:timeout, :election_timeout}, Raft.GenTimeout.call(), :start_election}]}
  end

  def follower({:timeout, :election_timeout}, _arg1, _arg2) do
    require IEx
    IEx.pry()
    Logger.info("Starting elections")
  end

  def follower(:cast, :data, data) do
    IO.inspect(data, label: "Data")
    {:keep_state_and_data, []}
  end

  # Writes as the follower
  # TODO: Didn't get an RPC for this yet
  def follower(
        :cast,
        write,
        state = %Raft.ServerState{
          last_index_applied: last_index_applied,
          leader_index: leader_index
        }
      )
      when leader_index > last_index_applied do
    # TODO: write to log, maybe just make the log in memory & punt on writing to disk for now

    {:keep_state,
     %Raft.ServerState{
       state
       | last_index_applied: last_index_applied + 1
     }, [{:next_event, :cast, write}]}
  end

  ### Votes Protocol

  # Doesn't vote when the term requested isn't beyond this server's current term.
  def follower(
        :cast,
        %{candidates_name: candidates_name, term: term} = %Raft.RequestVote{},
        _data = %Raft.ServerState{current_term: current_term}
      )
      when term < current_term do
    Logger.info("#{inspect(self())} responded to vote #{false} for #{inspect(candidates_name)}")

    GenStateMachine.cast(candidates_name, %Raft.RequestVoteResponse{
      term: term,
      granted: false
    })

    # No change
    {:keep_state_and_data, []}
  end

  # Votes for a request if a candidate requests it (and is still a follower), but only if the
  # conditions are met, that their index is at least your index, their term is at least your term
  # AND that you haven't voted for someone already.
  #
  # Once those steps have been taken, you move into `:start` as a follower.
  def follower(
        :cast,
        %Raft.RequestVote{
          term: term,
          candidates_name: candidates_name,
          candidates_last_index_applied: candidates_last_index_applied,
          candidates_last_term: candidates_last_term
        },
        data = %Raft.ServerState{
          voted_for: voted_for,
          last_index_applied: last_index_applied,
          current_term: current_term
        }
      )
      when candidates_last_index_applied >= last_index_applied and
             candidates_last_term >= current_term and
             voted_for in [nil, candidates_name] do
    Logger.info("#{inspect(self())} responded to vote true for #{inspect(candidates_name)}")

    GenStateMachine.cast(candidates_name, %Raft.RequestVoteResponse{
      term: term,
      granted: true
    })

    # Bring us back to the initial state per §5.2
    {:keep_state, %Raft.ServerState{data | voted_for: candidates_name, current_term: term},
     [{:next_event, :cast, :start}]}
  end

  # Default cast does nothing
  def follower(:cast, event, data) do
    Logger.info("Does nothing")
    Logger.info(event)
    Logger.info(data)
    {:keep_state_and_data, []}
  end

  ###
  # Synchronous Events: All these have to return a message to the caller.
  ###

  # If a follower is requested to write something, redirect it to the leader
  def follower({:call, from}, {:write, _write}, data) do
    {:keep_state_and_data, [{:message, from, {:error, {:redirect, data.leader}}}]}
  end

  # Returns the data that the follower knows
  def follower({:call, from}, :data, data) do
    {:keep_state_and_data, [{:message, from, data}]}
  end

  # Returns who the leader is
  def follower({:call, from}, :leader, data) do
    {:keep_state_and_data, [{:reply, from, data.leader}]}
  end

  # When it's not an allowed event, default to returning an error tuple
  def follower({:call, from}, _event, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_event}}]}
  end

  # defdelegate follower, to: Raft.Follower
  # defdelegate candidate, to: Raft.Candidate
end
