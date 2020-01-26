defmodule Board do
  @moduledoc """

  Board is a module in charge of managing a TicTacToe board

  """
  # Replace/Create an empty board in the current game_state
  def empty(game_state, n) do
    game_state
    |> Map.delete(:board)
    |> Map.put(:board, empty_board(n))
    |> Map.delete(:n)
    |> Map.put(:n, n)
    |> Map.delete(:game_history)
    |> Map.put(:game_history, [])
  end

  defp empty_board(n), do: Matrex.zeros(n)

  defp add_current_board_to_history(game_state) do
    hashed_board =
      game_state
      |> Board.hash()

    new_history = (game_state |> Map.get(:game_history)) ++ [hashed_board]

    game_state
    |> Map.update!(:game_history, fn _ -> new_history end)
  end

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
    |> add_current_board_to_history()
  end

  def addPlayer(game_state, symbol) do
    game_state |> Map.delete(symbol) |> Map.put(symbol, %{})
  end

  # Simply check if there's a winner in the board
  def winner?(game_state) do
    x = game_state |> Map.get(:n)
    y = game_state |> Map.get(:n)
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
    size = board |> Matrex.size() |> elem(0)

    winner_row =
      board
      |> Matrex.row(y)
      |> Matrex.to_list()
      |> Enum.reduce(0, &+/2)
      |> (fn f -> abs(f) == size end).()

    winner_row || winner_rows(board, x, y - 1)
  end

  # Check if there's a winner in the columns
  defp winner_cols(board, x, y) do
    board
    |> Matrex.transpose()
    |> winner_rows(x, y)
  end

  # Calculates if there's a winner in the diagonals
  defp winner_diag(board, _x, y) do
    size = board |> Matrex.size() |> elem(0)

    abs(winner_d1(board)) == size || abs(winner_d2(board, 1, y)) == size
  end

  # This checks the diagonal \
  defp winner_d1(board) do
    board
    |> Matrex.diagonal()
    |> Matrex.to_list()
    |> Enum.reduce(0, &+/2)
  end

  # This checks the diagonal /
  defp winner_d2(_board, _, 0), do: 0
  defp winner_d2(board, x, y), do: board[x][y] + winner_d2(board, x + 1, y - 1)

  def print(game_state) do
    board = get_board(game_state)
    size_x = Matrex.size(board) |> elem(0)
    size_y = Matrex.size(board) |> elem(1)

    for y <- 1..size_y do
      for x <- 1..size_x do
        if board[x][y] == Symbol.x() do
          IO.write(" X ")
        else
          if board[x][y] == Symbol.o() do
            IO.write(" O ")
          else
            IO.write(" . ")
          end
        end
      end

      IO.puts("")
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
    # This assumes the board is always a square
    |> elem(0)
  end

  # defp empty_position?(game_state, x, y) do
  #   board = Board.get_board(game_state)

  #   board[x][y] == 0.0
  # end

  def get_available_positions(game_state) do
    board = Board.get_board(game_state)
    board_size = Board.size(game_state)

    max_x = board_size
    max_y = board_size

    for i <- 1..max_x, j <- 1..max_y, board[i][j] == 0, do: {i, j}
  end

  def hash(game_state) do
    board = Board.get_board(game_state)
    board_size = Board.size(game_state)
    max_x = board_size
    max_y = board_size

    board_array = for i <- 1..max_x, j <- 1..max_y, do: board[i][j]

    board_array
    |> Enum.join("!")
  end

  def get_history(game_state) do
    game_state
    |> Map.get(:game_history)
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

defmodule Player do
  def play(game_state, symbol) do
    # Some moves are random just to spice the player
    best_move =
      if Enum.random(1..10) <= 3 do
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
    |> Enum.reduce(%{best_reward: -99_999_999, best_position: nil}, fn pos, acc ->
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
      # Neutral position
      nil -> 0.0
      # Learned value
      position_value -> position_value
    end
  end

  def reinforce(game_state, symbol, value, step) do
    board_hash_list =
      game_state
      |> Board.get_history()
      |> Enum.reverse()

    game_state
    |> repoint_boards(board_hash_list, symbol, value, step)
  end

  # Repoints all the boards on a given game
  # No more boards to repoint
  defp repoint_boards(gs, [], _, _, _), do: gs

  defp repoint_boards(game_state, board_hash_list, symbol, value, step) do
    [board_hash | tail] = board_hash_list

    game_state
    |> reevaluate_board(board_hash, symbol, value)
    # |> repoint_boards(tail, symbol, value + step, step)
    |> repoint_boards(tail, symbol, value + step, step)
  end

  defp reevaluate_board(game_state, board_hash, symbol, new_value) do
    player_status =
      game_state
      |> Map.get(symbol)

    board_value =
      player_status
      |> Map.get(board_hash)

    updated_player =
      case board_value do
        # not pointed yet
        nil ->
          player_status
          |> Map.put(board_hash, new_value)

        # board already has some value
        old_value ->
          player_status
          |> Map.update!(board_hash, fn _ -> old_value + new_value end)
      end

    game_state
    |> Map.update!(symbol, fn _ -> updated_player end)
  end
end

defmodule TicTacToe do
  @moduledoc """

  TicTacToe uses Reinforcement Learning to train two players
  to learn how to play Tic-Tac-Toe

  """
  def start(n) do
    new_state()
    |> Board.empty(n)
    |> Board.addPlayer(Symbol.x())
    |> Board.addPlayer(Symbol.o())
  end

  def train(game_state, 0), do: game_state

  # Trains the game
  def train(game_state, times) do
    IO.write("Training game #{times} : ")

    game_state
    |> game_end?(false)
    |> train(times - 1)
  end

  def game_end?(game_state, true), do: game_state |> Board.empty(Board.size(game_state))

  def game_end?(game_state, false) do
    game_state = game_state |> Player.play(Symbol.x())

    # WINNER X
    if Board.winner?(game_state) do
      IO.puts("Winner X")

      game_state
      |> Player.reinforce(Symbol.x(), 1, -0.05)
      |> Player.reinforce(Symbol.o(), -1, 0.05)
      |> game_end?(true)
    else
      # TIE
      if Enum.empty?(Board.get_available_positions(game_state)) do
        IO.puts("TIE!")

        game_state
        |> Player.reinforce(Symbol.x(), 0.5, -0.01)
        |> Player.reinforce(Symbol.o(), 0.7, -0.02)
        |> game_end?(true)
      else
        game_state = game_state |> Player.play(Symbol.o())
        # WINNER O
        if game_state |> Board.winner?() do
          IO.puts("Winner O")

          game_state
          |> Player.reinforce(Symbol.x(), -1, 0.05)
          |> Player.reinforce(Symbol.o(), 1, -0.05)
          |> game_end?(true)
        else
          # TIE
          if Enum.empty?(Board.get_available_positions(game_state)) do
            IO.puts("TIE!")

            game_state
            |> Player.reinforce(Symbol.x(), 0.5, -0.01)
            |> Player.reinforce(Symbol.o(), 0.7, -0.02)
            |> game_end?(true)
          else
            game_end?(game_state, false)
          end
        end
      end
    end
  end

  defp new_state(), do: %{}

  def play_against(game_state, symbol) do
    game_state
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
    |> Player.play(symbol)
    |> Board.print()
    |> Human.move()
  end
end

defmodule Human do
  def move(game_state) do
    IO.puts("Row?")
    row = IO.read(:stdio, :line) |> String.trim() |> String.to_integer()
    IO.puts("Col?")
    col = IO.read(:stdio, :line) |> String.trim() |> String.to_integer()

    Board.play(game_state, Symbol.o(), {col, row})
  end
end

gs =
  TicTacToe.start(3)
  |> TicTacToe.train(2000)
  |> TicTacToe.play_against(Symbol.x())

require IEx
IEx.pry()
