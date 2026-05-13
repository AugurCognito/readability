defmodule Readability.Sanitizer do
  @moduledoc """
  Cleans article HTML trees by removing fishy elements.

  Uses an algorithm based on content length, class names, link density,
  number of images/embeds, and other heuristics.
  """

  alias Readability.Candidate
  alias Readability.Candidate.Scoring
  alias Readability.Helper
  alias Readability.Queries

  @type html_tree :: tuple | list

  @doc """
  Sanitizes an article HTML tree by removing headlines, unlikely tags,
  empty paragraphs, and optionally performing conditional cleaning.
  """
  @spec sanitize(html_tree, [Candidate.t()], list) :: html_tree
  def sanitize(html_tree, candidates, opts \\ []) do
    html_tree =
      html_tree
      |> Helper.remove_tag(&clean_headline_tag?/1)
      |> Helper.remove_tag(&clean_unlikely_tag?/1)
      |> Helper.remove_tag(&clean_empty_p?/1)

    if opts[:clean_conditionally] do
      Helper.remove_tag(html_tree, conditionally_cleaning_fn(candidates))
    else
      html_tree
    end
  end

  defp conditionally_cleaning_fn(candidates) do
    fn {tag, attrs, _} = tree ->
      if tag in ["table", "ul", "div"] do
        weight = Scoring.class_weight(attrs)

        same_tree =
          Enum.find(candidates, %Candidate{}, &(&1.html_tree == tree))

        list? = tag == "ul"

        cond do
          weight + same_tree.score < 0 ->
            true

          Queries.count_character(tree, ",") < 10 ->
            p_len = tree |> Queries.find_tag("p") |> length()
            img_len = tree |> Queries.find_tag("img") |> length()
            li_len = tree |> Queries.find_tag("li") |> length()
            input_len = tree |> Queries.find_tag("input") |> length()

            embed_len =
              tree
              |> Queries.find_tag("embed")
              |> Enum.reject(&(Queries.text(&1) =~ Readability.regex(:video)))
              |> length()

            link_density = Scoring.calc_link_density(tree)
            content_len = Queries.text_length(tree)

            img_len > p_len || (!list? && li_len > p_len) || input_len > p_len / 3 ||
              (!list? && content_len < 25 && img_len != 1) ||
              (weight < 25 && link_density > 0.2) || (weight >= 25 && link_density > 0.5) ||
              ((embed_len == 1 && content_len < 75) || embed_len > 1)

          true ->
            false
        end
      end
    end
  end

  defp clean_headline_tag?({tag, attrs, _} = html_tree) do
    tag =~ ~r/^h\d{1}$/ &&
      (Scoring.class_weight(attrs) < 0 || Scoring.calc_link_density(html_tree) > 0.33)
  end

  defp clean_unlikely_tag?({tag, attrs, _}) do
    attrs_str = Enum.map_join(attrs, "", &elem(&1, 1))
    tag =~ ~r/form|object|iframe|embed/ && !(attrs_str =~ Readability.regex(:video))
  end

  defp clean_empty_p?({tag, _, _} = html_tree) do
    tag == "p" && Queries.text_length(html_tree) == 0
  end
end
