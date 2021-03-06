defmodule Hangman.Handler.Accumulator do
  @moduledoc """
  Module implements an accumulator which builds up a sequence list
  in the context of a game client handler.  Hides the details of the functional 
  reduce-while-cycle trickery
  """

  @doc """
  Repeatedly builds up an accumulator sequence using next(value) until we invoke done
  """

  defmacro repeatedly(do: block) do
    # Create AST
    quote do
      # We create the loop by running a Stream.cycle with Enum.reduce_while
      # we reverse the prepended acc list of round statuses
      list =
        Enum.reduce_while(Stream.cycle([:ok]), [], fn _, acc ->
          # Inject the loop block
          result = unquote(block)

          # Look at the last line of the block and 
          # construct the proper line for Enum.reduce_while

          # We simply prepend to the acc
          case result do
            # prepend O(1)
            {:cont, value} ->
              {:cont, [value | acc]}

            {:halt} ->
              {:halt, acc}

            # prepend O(1)
            {:halt, value} ->
              {:halt, [value | acc]}

            # If nothing explicitly specified in last loop line we just continue
            _ ->
              {:cont, acc}
          end
        end)
        |> Enum.reverse()

      list
    end
  end

  # Constructs Enum.take_while specific iteration tuples to be folded above
  def next, do: {:cont}
  def next(value), do: {:cont, value}

  def done, do: {:halt}
  def done(value), do: {:halt, value}
end
