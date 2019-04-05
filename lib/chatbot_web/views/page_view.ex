defmodule ChatbotWeb.PageView do
  use ChatbotWeb, :view

  def render("chat.json", %{response: message}) do
    message
  end
end
