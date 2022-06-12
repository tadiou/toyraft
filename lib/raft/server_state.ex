defmodule Raft.ServerState do
  @type t :: %Raft.ServerState{
          this_server: integer,
          current_term: integer,
          voted_for: atom | nil,
          who_is_the_leader: atom | nil,
          votes_obtained: integer,
          other_servers: list,
          last_index_applied: integer,
          leader_index: integer,
          log: [Raft.Entry.t()]
        }

  defstruct this_server: nil,
            current_term: 0,
            voted_for: nil,
            who_is_the_leader: nil,
            votes_obtained: 0,
            other_servers: [],
            last_index_applied: 0,
            leader_index: 0,
            log: []
end
