defmodule Readability.Candidate.Scoring do
  @moduledoc """
  Scores HTML tree nodes based on content heuristics.

  Considers element type, class/id weight, text density, link density,
  and content depth to produce a readability score.
  """

  alias Readability.Queries

  @element_scores %{"div" => 5, "blockquote" => 3, "form" => -3, "th" => -5}

  @type html_tree :: tuple | list
  @type options :: list

  @doc """
  Scores an HTML tree node using content analysis heuristics.

  Combines node score, children/grandchildren content scores, and
  penalizes by link density.
  """
  @spec calc_score(html_tree, options) :: number
  def calc_score(html_tree, opts \\ []) do
    score = calc_node_score(html_tree, opts)

    score =
      score + calc_children_content_score(html_tree) +
        calc_grand_children_content_score(html_tree)

    score * (1 - calc_link_density(html_tree))
  end

  defp calc_content_score(html_tree) do
    score = 1
    split_score = Queries.count_character(html_tree, ",") + 1
    length_score = min(Queries.text_length(html_tree) / 100, 3)
    score + split_score + length_score
  end

  defp calc_node_score({tag, attrs, _}, opts) do
    score = 0
    score = if opts[:weight_classes], do: score + class_weight(attrs), else: score
    score + (@element_scores[tag] || 0)
  end

  defp calc_node_score([h | t], opts) do
    calc_node_score(h, opts) + calc_node_score(t, opts)
  end

  defp calc_node_score([], _), do: 0

  @doc """
  Calculates a weight based on the class and id attributes.

  Positive class/id patterns add weight; negative patterns subtract.
  """
  @spec class_weight(list) :: number
  def class_weight(attrs) do
    weight = 0
    class = attrs |> List.keyfind("class", 0, {"", ""}) |> elem(1)
    id = attrs |> List.keyfind("id", 0, {"", ""}) |> elem(1)

    weight = if class =~ Readability.regex(:positive), do: weight + 25, else: weight
    weight = if id =~ Readability.regex(:positive), do: weight + 25, else: weight
    weight = if class =~ Readability.regex(:negative), do: weight - 25, else: weight
    weight = if id =~ Readability.regex(:negative), do: weight - 25, else: weight
    weight
  end

  @doc """
  Calculates the ratio of link text to total text in a node.
  """
  @spec calc_link_density(html_tree) :: float
  def calc_link_density(html_tree) do
    text_length = Queries.text_length(html_tree)

    if text_length == 0 do
      0
    else
      link_length =
        html_tree
        |> Queries.find_tag("a")
        |> Queries.text_length()

      link_length / text_length
    end
  end

  defp calc_children_content_score({_, _, children_tree}) do
    children_tree
    |> Enum.filter(&(is_tuple(&1) && Readability.CandidateFinder.candidate_tag?(&1)))
    |> calc_content_score()
  end

  defp calc_grand_children_content_score({_, _, children_tree}) do
    score =
      children_tree
      |> Enum.filter(&is_tuple(&1))
      |> Enum.map(&elem(&1, 2))
      |> List.flatten()
      |> Enum.filter(&(is_tuple(&1) && Readability.CandidateFinder.candidate_tag?(&1)))
      |> calc_content_score()

    score / 2
  end
end
