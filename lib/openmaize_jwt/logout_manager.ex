defmodule OpenmaizeJWT.LogoutManager do
  use GenServer

  import OpenmaizeJWT.Verify

  @sixty_mins 3_600_000
  @logout_state Path.join(Application.app_dir(:openmaize_jwt, "priv"), "logout_state.json")

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Process.flag(:trap_exit, true)
    state = case File.read(@logout_state) do
      {:ok, state} -> Poison.decode!(state)
      {:error, _} -> Map.new()
    end
    File.rm @logout_state
    Process.send_after(self(), :clean, @sixty_mins)
    {:ok, state}
  end

  def get_state(), do: GenServer.call(__MODULE__, :get_state)

  def query_jwt(jwt), do: GenServer.call(__MODULE__, {:query, jwt})

  def store_jwt(jwt), do: GenServer.cast(__MODULE__, {:push, jwt, exp_value(jwt)})

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  def handle_call({:query, jwt}, _from, state) do
    {:reply, Map.has_key?(state, jwt), state}
  end

  def handle_cast({:push, jwt, time}, state) do
    {:noreply, Map.put(state, jwt, time)}
  end

  def handle_info(:clean, state) do
    Process.send_after(self(), :clean, @sixty_mins)
    {:noreply, clean_store(state)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def code_change(_old, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, state) do
    File.write @logout_state, Poison.encode!(state)
    :ok
  end

  defp clean_store(store) do
    time = System.system_time(:milli_seconds)
    :maps.filter fn _, y -> y > time end, store
  end
end
