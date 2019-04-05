defmodule ChatbotWeb.PageController do
  use ChatbotWeb, :controller

  defp config() do
    [{"help", &Chatbot.Bot.help/3},
     {"create", &Chatbot.Bot.createMeme/3},
     {"alias", &Chatbot.Bot.createTemplate/3},
     {"view", &Chatbot.Bot.viewTemplate/3},
     {"popular", &Chatbot.Bot.popularTemplates/3},
     {"list", &Chatbot.Bot.list/3}]
  end

  def index(conn, _params) do
    render(conn, "index.html")
  end

  defp dispatch(_params, _lowerCommand, _command, []), do: %{}
  defp dispatch(params, lowerCommand, command, [{prefix, fun} | args]) do
    case String.starts_with?(lowerCommand, prefix) do
      true ->
        IO.puts("Matched command #{prefix}")
        fun.(prefix, params, command)
      false ->
        dispatch(params, lowerCommand, command, args)
    end
  end

  def chat(conn, params) do\
    IO.puts("#{inspect params}")
    command = String.trim_leading(params["message"]["argumentText"])
    response = dispatch(params, String.downcase(command), command, config())
    IO.puts("#{inspect response}")

    render conn, "chat.json", response: response
  end
end
