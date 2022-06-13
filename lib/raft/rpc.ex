defmodule Raft.AppendEntry do
  @type t :: %Raft.AppendEntry{
          term: integer,
          who_is_the_leader: atom | nil,
          previous_index_applied: integer,
          previous_term: integer,
          entries_to_store: [Raft.Entry.t()]
        }
  defstruct term: -1,
            who_is_the_leader: nil,
            previous_index_applied: -1,
            previous_term: -1,
            entries_to_store: []
end

defmodule Raft.AppendEntryResponse do
  @type t :: %Raft.AppendEntryResponse{
          term: integer,
          success: boolean,
          last_index_applied: integer,
          last_term: integer
        }
  defstruct term: -1,
            success: false,
            last_index_applied: -1,
            last_term: -1
end

defmodule Raft.RequestVote do
  @type t :: %Raft.RequestVote{
          term: integer,
          candidates_name: atom | nil,
          candidates_last_index_applied: integer,
          candidates_last_term: integer
        }

  defstruct term: -1,
            candidates_name: nil,
            candidates_last_index_applied: -1,
            candidates_last_term: -1
end

defmodule Raft.RequestVoteResponse do
  @type t :: %Raft.RequestVoteResponse{
          term: integer,
          granted: boolean
        }
  defstruct term: -1,
            granted: false
end
