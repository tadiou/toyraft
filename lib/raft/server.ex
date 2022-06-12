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

  def init([this_server, other_servers, opts]) do
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

  #
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

  def follower(:cast, _event, _data) do
    {:keep_state_and_data, []}
  end

  ### Votes
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
          log: [{from_term, at_index, _value} | _rest]
        }
      ) do
    Logger.info("#{inspect(self())} responded to vote #{voted_for} for #{inspect(candidate)}")

    GenStateMachine.cast(candidates_name, %Raft.RequestVoteResponse{
      term: term,
      granted: voted_for
    })
  end

  ###
  # Synchronous Events
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

  # Need to ACTUALLY start writing candidate code
  # I can't actually deduce if it's # of servers total, or other servers that's the dividing line
  # for winning an election. If it's 12, but 11 other, you should need 6? You vote for yourself
  # of course.
  def candidate(
        :cast,
        %Raft.RequestVoteResponse{granted: true},
        data = %Raft.ServerState{votes_obtained: previous_votes_obtained, other_servers: servers}
      ) do
    votes_obtained = previous_votes_obtained + 1
    servers_count = servers |> length
    votes_needed = servers_count / 2

    Logger.info(
      "#{data.this_server} received a vote, #{votes_obtained} obtained, #{votes_needed} needed"
    )

    if votes_obtained > votes_needed do
      # Become Leader
    else
      {:keep_state, %Raft.ServerState{data | votes_obtained: votes_obtained}, []}
    end
  end

  # send RequestVote to all other servers
  def candidate(
        :cast,
        :request_vote,
        data = %Raft.ServerState{
          this_server: this_server,
          other_servers: other_servers,
          votes_obtained: votes_obtained,
          current_term: current_term,
          log: [
            %{from_term: this_servers_last_term, at_index: this_servers_last_index} =
              %Raft.Entry{}
            | _rest
          ]
        }
      ) do
    Logger.info("#{data.this_server} is requesting votes from other servers")

    other_servers
    |> Enum.each(fn server ->
      GenStateMachine.cast(server, %Raft.RequestVote{
        term: current_term + 1,
        candidates_name: this_server,
        candidates_last_index_applied: this_servers_last_index,
        candidates_last_term: this_servers_last_term
      })
    end)

    {:keep_state,
     %Raft.ServerState{
       data
       | current_term: current_term + 1,
         voted_for: me,
         votes_obtained: votes_obtained(+1)
     }, [{{:timeout, :election_timeout}, Raft.GenTimeOut.call(), :start_election}]}
  end

  # The below is old and should be deleted
  # Should just probably add a guard clause to return false
  @spec request_vote(any, any, any, any) :: {:ok, boolean}
  def request_vote(term, _, _, _) when 0 > term do
    {:ok, false}
  end

  def request_vote(term, candidate_id, last_log_index, last_log_term) do
    {:ok, true}
  end
end
