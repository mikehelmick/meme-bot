defmodule Chatbot.Environment do

  def project() do
    get_env("PROJECT", "")
  end

  def memeService() do
    get_env("MEME", "https://meme-fpz6derz7a-uc.a.run.app")
  end

  def token() do
    get_env("TOKEN", nil)
  end

  def get_env(name, default) do
    parse_string_env(System.get_env(name), default)
  end

  defp parse_string_env(nil, default), do: default
  defp parse_string_env(val, _), do: val

  defp parse_int_env(nil, default) do
    default
  end
  defp parse_int_env(val_s, default) do
    case Integer.parse(val_s) do
      {x, _} when is_integer(x) -> x
      _ -> default
    end
  end

  def get_int_env(name, default) do
    parse_int_env(System.get_env(name), default)
  end

  defp parse_bool_env("true", _), do: true
  defp parse_bool_env("false", _), do: false
  defp parse_bool_env(_, default) do
    default
  end

  def get_bool_env(name, default) do
    parse_bool_env(System.get_env(name), default)
  end
end
