defmodule Raft.Server do
  @moduledoc """
  The server which implements raft on a given node.

  """

  use GenStateMachine, callback_mode: :state_functions

  @type state :: :leader | :follower | :candidate

  def start_link(this_node, other_nodes, opts \\ []) do
    GenStateMachine.start_link(__MODULE__, [this_node, other_nodes], name: this_node)
  end

  # Should just probably add a guard clause to return false
  def request_vote(term, _, _, _) when 0 > term do
    {:ok, false}
  end

  def request_vote(term, candidate_id, last_log_index, last_log_term) do
  end
end
