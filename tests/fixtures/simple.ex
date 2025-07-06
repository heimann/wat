# Elixir test fixture
defmodule Point do
  @moduledoc "A point in 2D space"
  
  @version "1.0.0"
  
  defstruct x: 0.0, y: 0.0
  
  def new(x, y) do
    %Point{x: x, y: y}
  end
  
  def distance(%Point{x: x1, y: y1}, %Point{x: x2, y: y2}) do
    dx = x1 - x2
    dy = y1 - y2
    :math.sqrt(dx * dx + dy * dy)
  end
  
  defp private_helper(value) do
    value * 2
  end
end

defprotocol Drawable do
  def draw(shape)
end

defimpl Drawable, for: Point do
  def draw(%Point{x: x, y: y}) do
    IO.puts("Point at (#{x}, #{y})")
  end
end

defmodule Utils do
  @global_config %{debug: false}
  
  def format(str) do
    String.trim(str)
  end
  
  defmacro debug_print(msg) do
    quote do
      IO.puts("DEBUG: #{unquote(msg)}")
    end
  end
end

defmodule Main do
  alias Utils, as: U
  
  def main(args \\ []) do
    IO.puts("Hello, Elixir!")
  end
  
  defp add(a, b), do: a + b
end