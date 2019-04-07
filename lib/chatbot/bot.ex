defmodule Chatbot.Bot do
  @moduledoc """
  Responds to well known commands
  """
  alias Chatbot.AliasEntity, as: AliasEntity
  alias Chatbot.Environment, as: Environment
  alias Chatbot.Datastore, as: Datastore

  defp addHeader(card, nil), do: card
  defp addHeader(card, ""), do: addHeader(card, nil)
  defp addHeader(card, title) do
    Map.put(card, "header", %{"title" => title})
  end

  defp textWidget(text) do
    %{textParagraph: %{text: text}}
  end

  defp imageWidget(imageUrl) do
    %{image: %{imageUrl: imageUrl}}
  end

  defp buttonWidget(text, link) do
    %{buttons: [
      %{textButton: %{
        text: text,
        onClick: %{openLink: %{url: link}}
       }}]}
  end

  defp textCard(title, text) do
    %{cards: [
      %{sections: [%{widgets: [textWidget(text)]}]}
        |> addHeader(title)
      ]}
  end

  defp keyValue(top, content) do
    %{keyValue:
      %{topLabel: top,
        content: content
      }}
  end

  def imageWithButton(title, imageUrl, buttonText) do
    %{cards: [
      %{sections: [
        %{widgets: [
          imageWidget(imageUrl),
          buttonWidget(buttonText, imageUrl)]}]}
        |> addHeader(title)
    ]}
  end

  def imageWithText(title, imageUrl, text) do
    %{cards: [
      %{sections: [
        %{widgets: [
          imageWidget(imageUrl),
          textWidget(text)]}]}
        |> addHeader(title)
    ]}
  end


  def help(_prefix, _params, _command) do
    %{cards: [
      %{sections: [
        %{widgets: [
          keyValue("Display this message", "help"),
          keyValue("Creates a meme from template + text",
                   "create [template] \"top\" \"bottom\""),
          keyValue("Creates a template for an image",
                    "alias [template] [url]"),
          keyValue("View the image associated with a template",
                   "view [template]"),
          keyValue("View (n) popular templates",
                   "popular [n]"),
          keyValue("List a bunch of templates",
                   "list")
          ]}]}
        |> addHeader("Cloud Run Memebot Commands")
    ]}
  end

  def createMeme(prefix, params, command) do
    spawn(fn() -> HTTPoison.get(Environment.memeService(), [], []) end)

    command = String.slice(command, String.length(prefix), String.length(command))
        |> String.trim()
    # Extract template name
    [name | _] = String.split(command)
    command = String.slice(command, String.length(name), String.length(command))
        |> String.trim()

    case String.split(command, "\"") do
      ["", top, _, bottom, "" | _] ->
        case Datastore.readEntity(AliasEntity.kind(), name, &AliasEntity.parseEntity/1) do
          nil ->
            textCard("404: Template Not Found",
                "Template '#{name}' does not exist.\nCreate templates with the 'create' command.")
          entity ->
            AliasEntity.addUse(entity)
              |> Datastore.updateEntity(&AliasEntity.toEntity/1)

            image = URI.encode("#{Environment.memeService()}?top=#{top}&bottom=#{bottom}&image=#{AliasEntity.imageUrl(entity)}")
            # senderName = params["message"]["sender"]["displayName"]
            imageWithButton("",
                            image,
                            "Open In Browser")
        end
      _ ->
        textCard("400: Unable to Parse create",
                 "#{prefix} [template] \"top in quotes\" \"bottom in quotes\"")
    end
  end

  # Create a meme template.
  # Command is: template name imageUrl
  def createTemplate(prefix, params, command) do
    [name, image | _] =
        String.slice(command, String.length(prefix), String.length(command))
          |> String.trim()
          |> String.split()
    senderEmail = params["message"]["sender"]["email"]

    case Datastore.readEntity(AliasEntity.kind(), name, &AliasEntity.parseEntity/1) do
      nil ->
        # Not found, create it.
        AliasEntity.new(name, image, senderEmail)
          |> Datastore.insertEntity(&AliasEntity.toEntity/1)

        imageWithText("Template created for #{senderEmail}", image,
                      "to view: view #{name}\nto use: create #{name} \"top\" \"bottom\"")
      _entity ->
        textCard("Error", "Template '#{name}' already exists.\nType 'view #{name}' to see it.")
    end
  end

  def viewTemplate(prefix, _params, command) do
    [name | _] =
      String.slice(command, String.length(prefix), String.length(command))
        |> String.trim() |> String.split()

    case Datastore.readEntity(AliasEntity.kind(), name, &AliasEntity.parseEntity/1) do
      nil ->
        textCard("404: Template Not Found", "Template '#{name}' does not exist.")
      entity ->
        imageWithButton("Teamplate: '#{name}'", AliasEntity.imageUrl(entity),
                        "Open Image In Browser")
    end
  end

  def list(_prefix, _params, _command) do
    gql = "SELECT * FROM Alias ORDER BY created_at DESC"
    case Datastore.queryByGQL(gql) do
      {batch, _query} ->
        case batch["entityResults"] do
          nil ->
            textCard("", "There are no templates, you should create one!")
          entityResults ->
            %{cards: [
              %{sections: [
                %{widgets: [
                  Enum.map(entityResults,
                    fn result -> AliasEntity.parseEntity(result) |> AliasEntity.name() end)
                    |> Enum.join(", ")
                    |> textWidget()]}]}
                |> addHeader("To view type: view [template]")
            ]}
        end
      _ ->
        textCard("500: Error",
                 "Sorry, I currently can't list templates.")
    end
  end

  def popularTemplates(prefix, _params, command) do
    nAsString =
      case String.slice(command, String.length(prefix), String.length(command))
          |> String.trim()
          |> String.split() do
        [] -> ""
        [x | _] -> x
      end
    n = case Integer.parse(nAsString) do
          :error -> 5 # default
          {x, _} -> min(x, 5)
        end

    IO.puts("'#{nAsString}' and '#{n}'")

    gql = "SELECT * FROM Alias ORDER BY uses DESC LIMIT #{n}"
    case Datastore.queryByGQL(gql) do
      {batch, _query} ->
        %{cards: [
          %{sections: [
            %{widgets:
              List.flatten(Enum.map(batch["entityResults"],
                fn result ->
                  entity = AliasEntity.parseEntity(result)
                  name = AliasEntity.name(entity)
                  url = AliasEntity.imageUrl(entity)
                  [textWidget(name),imageWidget(url)]
                end))
             }]}
            |> addHeader("Popular Templates")
        ]}
      _ ->
        textCard("500: Error",
                 "Sorry, I currently can't load poupular templates.")
    end
  end
end
