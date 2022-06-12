defmodule Raft.ServerState do
  @type t() :: %Raft.ServerState{
          this_server: nil,
          current_term: 0,
          voted_for: nil,
          who_is_the_leader: nil,
          votes_obtained: 0,
          other_servers: [],
          last_index_applied: 0,
          leader_index: 0
        }

  defstruct this_server: nil,
            current_term: 0,
            voted_for: nil,
            who_is_the_leader: nil,
            votes_obtained: 0,
            other_servers: [],
            last_index_applied: 0,
            leader_index: 0
end
