defmodule NeonPredict do
  use Rustler,
    otp_app: :neon,
    crate: :neon_predict

  @default_aggregate_length 288

  def stock(symbol), do: stock(symbol, @default_aggregate_length)

  def stock(%{id: symbol_id} = symbol, length) when is_integer(length) do
    aggregates =
      Neon.Stock.list_aggregates(
        limit: length,
        symbol_id: symbol_id,
        width: "5 minutes"
      )

    stock(symbol, aggregates)
  end

  def stock(_symbol, aggregates) do
    data = Enum.map(aggregates, &cast_aggregate/1)
    predict_stock(data)
  end

  defp cast_aggregate(aggregate) do
    %{
      open_price: Decimal.to_float(aggregate.open_price),
      high_price: Decimal.to_float(aggregate.high_price),
      low_price: Decimal.to_float(aggregate.low_price),
      close_price: Decimal.to_float(aggregate.close_price),
      volume: aggregate.volume,
      timestamp: aggregate.inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    }
  end

  def predict_stock(_), do: :erlang.nif_error(:nif_not_loaded)
end
