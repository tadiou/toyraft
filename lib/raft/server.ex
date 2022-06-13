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

  defdelegate follower, to: Raft.Follower

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
