defmodule Raft.Candidate do
  @moduledoc """
  Contains the candidate GenStateMachine code
  """

  # Need to ACTUALLY start writing candidate code
  # I can't actually deduce if it's # of servers total, or other servers that's the dividing line
  # for winning an election. If it's 12, but 11 other, you should need 6? You vote for yourself
  # of course.
  def(
    candidate(
      :cast,
      %Raft.RequestVoteResponse{granted: true},
      data = %Raft.ServerState{
        votes_obtained: previous_votes_obtained,
        other_servers: servers
      }
    )
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
         voted_for: this_server,
         votes_obtained: votes_obtained + 1
     }, [{{:timeout, :election_timeout}, Raft.GenTimeout.call(), :start_election}]}
  end
end
