defmodule Readability.Candidate.Cleaner do
  @moduledoc """
  Cleans the HTML tree to prepare candidates for scoring.

  Transforms misused tags and removes unlikely candidate nodes.
  """

  alias Readability.Helper

  @type html_tree :: tuple | list

  @doc """
  Transforms `<div>` tags that do not contain block-level elements into `<p>` tags.
  """
  @spec transform_misused_div_to_p(html_tree) :: html_tree
  def transform_misused_div_to_p(content) when is_binary(content), do: content
  def transform_misused_div_to_p([]), do: []

  def transform_misused_div_to_p([h | t]) do
    [transform_misused_div_to_p(h) | transform_misused_div_to_p(t)]
  end

  def transform_misused_div_to_p({tag, attrs, inner_tree}) do
    tag = if misused_divs?(tag, inner_tree), do: "p", else: tag
    {tag, attrs, transform_misused_div_to_p(inner_tree)}
  end

  @doc """
  Removes nodes that are unlikely to be article content.
  """
  @spec remove_unlikely_tree(html_tree) :: html_tree
  def remove_unlikely_tree(html_tree) do
    Helper.remove_tag(html_tree, &unlikely_tree?(&1))
  end

  defp misused_divs?("div", inner_tree) do
    inner_html = inner_tree |> List.wrap() |> LazyHTML.Tree.to_html()
    !(inner_html =~ Readability.regex(:div_to_p_elements))
  end

  defp misused_divs?(_, _), do: false

  defp unlikely_tree?({tag, attrs, _}) do
    idclass_str =
      attrs
      |> Enum.filter(fn {k, _} -> k =~ ~r/id|class/i end)
      |> Enum.map_join("", fn {_, v} -> v end)

    str = tag <> idclass_str

    str =~ Readability.regex(:unlikely_candidate) &&
      !(str =~ Readability.regex(:ok_maybe_its_a_candidate)) && tag != "html"
  end
end
