defmodule Chatbot.Keys do

  def build_path_key(key_paths) when is_list(key_paths) do
    %GoogleApi.Datastore.V1.Model.Key {
      path: Enum.map(key_paths,
        fn {kind, id} ->
          %GoogleApi.Datastore.V1.Model.PathElement{
            kind: kind,
            name: id
          }
        end)
    }
  end

  defp build_keys(_kind, [], keys) do
    keys
  end
  defp build_keys(kind, [id | rest], keys) do
    key = %GoogleApi.Datastore.V1.Model.Key {
      path: [
        %GoogleApi.Datastore.V1.Model.PathElement{
          kind: kind,
          name: id
        }
      ]
    }
    build_keys(kind, rest, keys ++ [key])
  end

  def build_keys(kind, ids) do
    build_keys(kind, ids, [])
  end

end
