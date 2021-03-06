defmodule Hangman.Letter.Strategy.Test do
  use ExUnit.Case, async: true

  alias Hangman.{Letter.Strategy, Pass, Counter}

  describe "Strategy retrieval common for a large pass" do
    setup :setup_large_pass

    test "self-selecting auto mode", %{letter: letter, pass: pass} do
      # Choose guess
      strategy = Strategy.new() |> Strategy.process(pass)

      assert {:guess_letter, ^letter} = Strategy.guess(strategy)
    end

    test "interactive choices mode", %{letter: letter, pass: pass} do
      # Choose guess
      strategy = Strategy.new() |> Strategy.process(:choices, pass)

      str =
        "Player fozzie, Round 3, WAKA WAKA.\n5 weighted letter choices :" <>
          "  i:4843 a*:4368 s:4334 o:3920 n:3736 (* robot choice)"

      assert {:guess_letter, str} ==
               Strategy.choices(strategy, %Hangman.Round{
                 id: "fozzie",
                 num: 3,
                 status_text: "WAKA WAKA"
               })

      assert {:guess_letter, letter} ==
               strategy |> Strategy.guess(:choices, {:guess_letter, letter})
    end
  end

  describe "Strategy retrieval common for a small pass" do
    setup :setup_small_pass

    test "self selecting auto mode", %{valid_letters: valid_letters, pass: pass} do
      # Choose guess
      strategy = Strategy.new() |> Strategy.process(pass)
      {:guess_letter, letter} = Strategy.guess(strategy)

      # Ensure the recommended letter guess is within the precalculated set
      assert letter in valid_letters
    end

    test "interactive choices mode", %{valid_letters: _valid_letters, pass: pass} do
      strategy = Strategy.new() |> Strategy.process(:choices, pass)

      str =
        "Possible hangman words left, 4 words: [\"conductors\", " <>
          "\"corruptors\", \"polygynous\", \"voluptuous\"]\n\nPlayer " <>
          "piggy, Round 1, KERMIE.\n5 weighted letter choices :  u:4 p:3 t:3 c*:2 l:2 (* robot choice)"

      assert {:guess_letter, str} ==
               Strategy.choices(strategy, %Hangman.Round{
                 id: "piggy",
                 num: 1,
                 status_text: "KERMIE"
               })
    end
  end

  describe "Strategy when last word reached" do
    setup :setup_last_pass

    test "self selecting auto mode", %{pass: pass} do
      token = "asparagus"

      # Choose guess
      strategy = Strategy.new() |> Strategy.process(pass)

      assert {:guess_word, ^token} = Strategy.guess(strategy)
    end

    test "interactive choices mode", %{pass: pass} do
      token = "asparagus"

      # Choose guess
      strategy = Strategy.new() |> Strategy.process(:choices, pass)

      assert {:guess_word, ^token,
              "Player kermit, Round 7, KEEP GUESSING.\nLast word left: asparagus"} =
               strategy
               |> Strategy.choices(%Hangman.Round{
                 id: "kermit",
                 num: 7,
                 status_text: "KEEP GUESSING"
               })
    end
  end

  describe "Strategy when pass is empty" do
    test "self selecting auto mode" do
      pass_info = %Pass{size: 0, tally: nil, last_word: "quasar", possible: ""}

      # Process pass

      assert catch_error(Strategy.new() |> Strategy.process(pass_info)) ==
               %HangmanError{message: "Word not in dictionary"}
    end

    test "interactive choices mode" do
      pass_info = %Pass{size: 0, tally: nil, last_word: "quasar", possible: ""}

      # Process pass

      assert catch_error(Strategy.new() |> Strategy.process(:choices, pass_info)) ==
               %HangmanError{message: "Word not in dictionary"}
    end
  end

  def setup_large_pass(_context) do
    eng_letter_freq = %{
      "a" => 8.167,
      "b" => 1.492,
      "c" => 2.782,
      "d" => 4.253,
      "e" => 12.702,
      "f" => 2.228,
      "g" => 2.015,
      "h" => 6.094,
      "i" => 6.966,
      "j" => 0.153,
      "k" => 0.772,
      "l" => 4.025,
      "m" => 2.406,
      "n" => 6.749,
      "o" => 7.507,
      "p" => 1.929,
      "q" => 0.095,
      "r" => 5.987,
      "s" => 6.327,
      "t" => 9.056,
      "u" => 2.758,
      "v" => 0.978,
      "w" => 2.360,
      "x" => 0.150,
      "y" => 1.974,
      "z" => 0.074
    }

    tally =
      Counter.new(%{
        "a" => 4368,
        "b" => 1190,
        "c" => 2458,
        "d" => 1570,
        "f" => 722,
        "g" => 2184,
        "h" => 1574,
        "i" => 4843,
        "j" => 92,
        "k" => 747,
        "l" => 2952,
        "m" => 1771,
        "n" => 3736,
        "o" => 3920,
        "p" => 1528,
        "q" => 88,
        "r" => 3157,
        "s" => 4334,
        "t" => 3189,
        "u" => 2078,
        "v" => 361,
        "w" => 614,
        "x" => 100,
        "y" => 1313,
        "z" => 151
      })

    tuple_list = Counter.items(tally)

    weighted =
      Enum.reduce(tuple_list, %{}, fn {k, v}, acc ->
        weighted_v = Map.get(eng_letter_freq, k) * v
        Map.put(acc, k, weighted_v)
      end)

    # Do a Schwartzian Transform
    # map the elements to a decorated value, sort the decorated value, 
    # and reflect that back in the new sorted order of the elements
    result = Enum.sort_by(weighted, &Kernel.elem(&1, 1), &>=/2)

    # Grab the highest weighted letter
    {letter, _} = List.first(result)

    pass_info = %Pass{last_word: "", size: 6697, tally: tally}

    [letter: letter, pass: pass_info]
  end

  def setup_small_pass(_context) do
    # word_set_size = %{micro: 2, tiny: 5, small: 9, large: 550}

    tally =
      Counter.new(%{
        "c" => 2,
        "d" => 1,
        "g" => 1,
        "l" => 2,
        "n" => 2,
        "p" => 3,
        "r" => 2,
        "t" => 3,
        "u" => 4,
        "v" => 1,
        "y" => 1
      })

    possible_txt =
      "Possible hangman words left, 4 words: [\"conductors\", \"corruptors\", \"polygynous\", \"voluptuous\"]"

    pass_info = %Pass{size: 4, tally: tally, last_word: "", possible: possible_txt}

    tuple_list = Counter.items(tally)

    filtered =
      Enum.reduce(tuple_list, %{}, fn {k, v}, acc ->
        if v <= pass_info.size / 2 do
          Map.put(acc, k, v)
        else
          acc
        end
      end)

    # Group sorted result by value
    # E.g.  %{1 => ["d", "g", "v", "y"], 2 => ["c", "l", "n", "r"]}

    result =
      filtered
      |> Enum.group_by(
        # v - group by v's value
        &Kernel.elem(&1, 1),
        # k - display k
        &Kernel.elem(&1, 0)
      )

    # Do a Schwartzian Transform
    # so that we can easily grab the first element
    # E.g.  [{2, ["c", "l", "n", "r"]}, {1, ["d", "g", "v", "y"]}]
    # And then {2, ["c", "l", "n", "r"]}

    {_, valid_letters} =
      result
      |> Enum.sort_by(&Kernel.elem(&1, 0), &>=/2)
      |> List.first()

    [valid_letters: valid_letters, pass: pass_info]
  end

  def setup_last_pass(_context) do
    token = "asparagus"
    tally = Counter.new(%{"p" => 1, "r" => 1, "s" => 1, "u" => 1})
    pass_info = %Pass{size: 1, tally: tally, last_word: token, possible: ""}

    [pass: pass_info]
  end
end
