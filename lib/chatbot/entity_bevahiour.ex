defmodule Chatbot.EntityBehviour do

  @callback kind() :: String.t

  @callback toEntity(data :: any) :: GoogleApi.Datastore.V1.Model.Entity

  @callback parseEntity(GoogleApi.Datastore.V1.Model.Entity) :: any
end
