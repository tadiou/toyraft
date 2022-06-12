defmodule Raft.GenTimeout do
  @moduledoc """
  Service to create a timeout value. For the future, this range would be set when the raft
  starts as part of a configuration, but for now, we'll hardcode the range.

  Also I might need to re-look at
  https://hashrocket.com/blog/posts/the-adventures-of-generating-random-numbers-in-erlang-and-elixir

  I don't feel like we need cryptographic strength rand here, but it might be useful
  """
  @range 150..200

  @doc """
  Returns a value in ms of which a server would timeout.
  """
  @spec call() :: integer
  def call() do
    @range |> Enum.random()
  end
end
