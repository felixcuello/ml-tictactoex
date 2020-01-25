defmodule Board do
  @moduledoc """

  Board is a module in charge of managing a TicTacToe board

  """
  # Replace/Create an empty board in the current game_state
  def empty(game_state, x, y) do
    game_state
    |> Map.delete(:board) |> Map.put(:board, empty_board(x))
    |> Map.delete(:x)     |> Map.put(:x, x)
    |> Map.delete(:y)     |> Map.put(:y, y)
  end

  defp empty_board(n), do: Matrex.zeros(n)

  # Plays and return the updated game_state
  def play(game_state, symbol, position) do
    col = position |> elem(1)
    row = position |> elem(0)

    updated_board =
      game_state
      |> Board.get_board()
      |> Matrex.update(row, col, fn _ -> symbol end)

    game_state
    |> Map.update!(:board, fn _ -> updated_board end)
  end

  def addPlayer(game_state, symbol) do
    game_state
    |> Map.delete(symbol) |> Map.put(symbol, %{})
  end

  # Simply check if there's a winner in the board
  def winner?(game_state) do
    x = game_state |> Map.get(:x)
    y = game_state |> Map.get(:y)
    board = Board.get_board(game_state)

    cond do
      winner_rows(board, x, y) -> true
      winner_cols(board, x, y) -> true
      winner_diag(board, x, y) -> true
      true -> false
    end
  end

  # Check if there's a winner in the rows
  defp winner_rows(_board, _x, 0), do: false
  defp winner_rows(board, x, y) do
    size = board |> Matrex.size |> elem(0)

    winner_row =
      board
      |> Matrex.row(y)
      |> Matrex.to_list
      |> Enum.reduce(0, &+/2)
      |> fn f -> abs(f) == size end.()

    winner_row || winner_rows(board, x, y-1)
  end

  # Check if there's a winner in the columns
  defp winner_cols(board, x, y) do
    board
    |> Matrex.transpose
    |> winner_rows(x, y)
  end

  # Calculates if there's a winner in the diagonals
  defp winner_diag(board, _x, y) do
    size = board |> Matrex.size |> elem(0)

    abs(winner_d1(board)) == size || abs(winner_d2(board, 1, y)) == size
  end

  # This checks the diagonal \
  defp winner_d1(board) do
    board
    |> Matrex.diagonal
    |> Matrex.to_list
    |> Enum.reduce(0, &+/2)
  end

  # This checks the diagonal /
  defp winner_d2(_board, _, 0), do: 0
  defp winner_d2(board, x, y), do: board[x][y] + winner_d2(board, x+1, y-1)

  def print(game_state) do
    board = get_board(game_state)
    size_x = Matrex.size(board) |> elem(0)
    size_y = Matrex.size(board) |> elem(1)

    for y <- 1..size_y do
      for x <- 1..size_x do
        IO.write "#{board[x][y]}    "
      end
      IO.puts "\n"
    end

    game_state
  end

  def get_board(game_state) do
    game_state
    |> Map.get(:board)
  end

  def size(game_state) do
    game_state
    |> get_board()
    |> Matrex.size()
  end

  # defp empty_position?(game_state, x, y) do
  #   board = Board.get_board(game_state)

  #   board[x][y] == 0.0
  # end

  def get_available_positions(game_state) do
    board = Board.get_board(game_state)
    board_size = Board.size(game_state)

    max_x = board_size |> elem(0)
    max_y = board_size |> elem(1)

    for i <- 1..max_x, j <- 1..max_y,
      board[i][j] == 0, do: {i, j}
  end

  def hash(game_state) do
    board = Board.get_board(game_state)
    board_size = Board.size(game_state)
    max_x = board_size |> elem(0)
    max_y = board_size |> elem(1)

    board_array = for i <- 1..max_x, j <- 1..max_y, do: board[i][j]

    board_array
    |> Enum.join("!")
  end
end

defmodule Symbol do
  @moduledoc """

  Returns the symbol for X / O player

  """
  @x_symbol 1
  @o_symbol -1

  def x(), do: @x_symbol
  def o(), do: @o_symbol
end

defmodule TicTacToe do
  @moduledoc """

  TicTacToe uses Reinforcement Learning to train two players
  to learn how to play Tic-Tac-Toe

  """
  def start(x,y) do
    new_state()
    |> Board.empty(x,y)
    |> Board.addPlayer(Symbol.x())
    |> Board.addPlayer(Symbol.o())
  end

  def train(game_state, 0), do: game_state

  # Trains the game
  def train(game_state, times) do
    game_state = game_state |> Player.play(Symbol.x())

    # CHequeo si gano el player X
    # si gano, reinforcement
    # si no gano, juega el player O
    # 

  end

  defp new_state(), do: %{}
end

defmodule Player do
  def play(game_state, symbol) do
    best_move =
    if Enum.random(1..10) <= 3 do # 30% of the time will play random :-)
      game_state
      |> Board.get_available_positions()
      |> Enum.take_random(1)
      |> List.first()
    else
      pick_best_move(game_state, symbol)
    end

    game_state
    |> Board.play(symbol, best_move)
  end

  # Try to pick the best move from the available positions
  def pick_best_move(game_state, symbol) do
    game_state
    |> Board.get_available_positions()
    |> Enum.reduce(%{best_reward: -99999999, best_position: nil}, fn pos, acc ->
      new_reward = Player.try_move(game_state, pos, symbol)

      if(new_reward > acc[:best_reward]) do
        acc
        |> Map.replace(:best_reward, new_reward)
        |> Map.replace(:best_position, pos)
      else
        acc
      end
    end)
    # |> fn x -> require IEx; IEx.pry end.() # Pause here if you want to check what was the reward for a move
    |> Map.get(:best_position)
  end

  # Try a move and return the learned value
  def try_move(game_state, position, symbol) do
    hash =
      game_state
      |> Board.play(symbol, position)
      |> Board.hash()

    case game_state |> Map.get(symbol) |> Map.get(hash) do
      nil -> 0.0 # Neutral position
      position_value -> position_value # Learned value
    end
  end
end

gs =
  TicTacToe.start(3,3)
  |> TicTacToe.train(1000)
  |> TicTacToe.human_vs_ai()

require IEx; IEx.pry
