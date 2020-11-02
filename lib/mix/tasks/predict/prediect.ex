defmodule Mix.Tasks.Predict.Predict do
  @moduledoc """
  Creates a prediction of stock forcast from past aggregate data.
  """

  use Mix.Task

  require Logger

  alias Neon.Stock

  @shortdoc "Creates a list of moving averages for a stock"
  def run([stock_symbol]) do
    start_services()

    symbol = Neon.Stock.get_symbol(symbol: stock_symbol)
    results = NeonPredict.stock(symbol)

    Mix.shell().info("Results for #{symbol.symbol} is #{results}")
  end

  def run([stock_symbol, length]) do
    start_services()

    symbol = Neon.Stock.get_symbol(symbol: stock_symbol)
    {length_number, _} = Integer.parse(length)
    results = NeonPredict.stock(symbol, length_number)

    Mix.shell().info("Results for #{symbol.symbol} is #{results}")
  end

  defp start_services(), do: Mix.Task.run("app.start")
end
