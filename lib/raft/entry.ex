defmodule Raft.Entry do
  @type t :: %Raft.Entry{
          from_term: integer,
          at_index: integer,
          value: {atom, any} | nil
        }
  defstruct from_term: -1,
            at_index: -1,
            value: nil
end
