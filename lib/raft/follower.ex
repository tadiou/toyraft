defmodule Raft.Follower do
  @moduledoc """
  Carries all the follower GenStateMachine behaviors
  """

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
  # Doesn't vote when the term is before
  def follower(
        :cast,
        %{term: term} = %Raft.RequestVote{},
        data = %Raft.ServerState{current_term: current_term}
      )
      when term > current_term do
  end

  # Votes for someone else when their current term > this current term
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
    Logger.info(
      "#{inspect(self())} responded to vote #{voted_for} for #{inspect(candidates_name)}"
    )

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
end
