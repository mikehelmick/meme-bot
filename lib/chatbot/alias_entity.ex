defmodule Chatbot.AliasEntity do
  @behaviour Chatbot.EntityBehviour
  alias Chatbot.Properties, as: Properties

  defstruct name: nil,
            imageUrl: nil,
            owner: nil,
            createdAt: nil,
            updatedAt: nil,
            uses: nil

  @type t :: %__MODULE__ {
    name: String.t(),
    imageUrl: String.t(),
    owner: String.t(),
    createdAt: nil,
    updatedAt: nil,
    uses: Integer.t()
  }

  def new(name, url, owner) do
    %Chatbot.AliasEntity {
      name: name,
      imageUrl: url,
      owner: owner,
      createdAt: DateTime.utc_now(),
      updatedAt: DateTime.utc_now(),
      uses: 0
    }
  end

  def kind(), do: "Alias"

  def name(%Chatbot.AliasEntity{name: name}), do: name
  def imageUrl(%Chatbot.AliasEntity{imageUrl: url}), do: url
  def owner(%Chatbot.AliasEntity{owner: owner}), do: owner
  def uses(%Chatbot.AliasEntity{uses: uses}), do: uses

  def addUse(entity = %Chatbot.AliasEntity {uses: uses}) do
    Map.put(entity, :uses, uses + 1)
  end

  def toEntity(%{name: name, imageUrl: imageUrl,
                 owner: owner, createdAt: createdAt,
                 updatedAt: updatedAt, uses: uses}) do
    %GoogleApi.Datastore.V1.Model.Entity {
      key: %GoogleApi.Datastore.V1.Model.Key {
        path: [
          %GoogleApi.Datastore.V1.Model.PathElement{
            kind: kind(),
            name: name
          }
        ]
      },
      properties: %{}
        |> Properties.setUnindexedString("imageUrl", imageUrl)
        |> Properties.set_string_property("owner", owner)
        |> Properties.set_datetime_property("created_at", createdAt)
        |> Properties.set_datetime_property("updated_at", updatedAt)
        |> Properties.set_integer_property("uses", uses)
    }
  end

  def parseEntity(entity) do
    parseQueryEntity(entity["entity"])
  end

  def parseQueryEntity(entity) do
    [path] = entity["key"]["path"]
    name = path["name"]
    properties = entity["properties"]
    %Chatbot.AliasEntity{
      name: name,
      imageUrl: Properties.parse_string(properties["imageUrl"]),
      owner: Properties.parse_string(properties["owner"]),
      createdAt: Properties.parse_timestamp(properties["created_at"]),
      updatedAt: Properties.parse_timestamp(properties["updated_at"]),
      uses: Properties.parse_int(properties["uses"])
    }
  end
end
