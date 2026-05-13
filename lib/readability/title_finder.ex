defmodule Readability.TitleFinder do
  @moduledoc """
  Extracts the article title from an HTML tree.

  Checks (in order): og:title meta tag, `<title>` tag, `<h1>` tag.
  """

  alias Readability.Queries

  @title_suffix ~r/\s(?:\-|\:\:|\|)\s/
  @h_tag_selector "h1"

  @type html_tree :: tuple | list

  @doc """
  Finds the best title from the HTML tree.
  """
  @spec title(html_tree) :: binary
  def title(html_tree) do
    case og_title(html_tree) do
      "" ->
        title = tag_title(html_tree)
        h_title = h_tag_title(html_tree)

        if good_title?(title) || h_title == "" do
          title
        else
          h_title
        end

      title when is_binary(title) ->
        title
    end
  end

  @doc """
  Finds the title from the `<title>` tag.
  """
  @spec tag_title(html_tree) :: binary
  def tag_title(html_tree) do
    html_tree
    |> find_tag_nodes("title")
    |> clean_title()
    |> String.split(@title_suffix)
    |> hd()
  end

  @doc """
  Finds the title from the `og:title` meta property.
  """
  @spec og_title(html_tree) :: binary
  def og_title(html_tree) do
    html_tree
    |> find_meta_content("og:title")
    |> clean_title()
  end

  @doc """
  Finds the title from an `<h>` tag.
  """
  @spec h_tag_title(html_tree, String.t()) :: binary
  def h_tag_title(html_tree, tag \\ @h_tag_selector) do
    html_tree
    |> find_tag_nodes(tag)
    |> clean_title()
  end

  # Find the first node matching a tag name
  defp find_tag_nodes(html_tree, tag) do
    case Queries.find_tag(html_tree, tag) do
      [] -> []
      [first | _] -> first
    end
  end

  # Find meta tag content by property value
  defp find_meta_content(html_tree, property) do
    html_tree
    |> Queries.find_tag("meta")
    |> Enum.find(fn {_, attrs, _} ->
      List.keyfind(attrs, "property", 0) == {"property", property}
    end)
    |> case do
      nil ->
        []

      {_, attrs, _} ->
        case List.keyfind(attrs, "content", 0) do
          {"content", value} -> [value]
          _ -> []
        end
    end
  end

  defp clean_title([]), do: ""

  defp clean_title([title]) when is_binary(title) do
    String.trim(title)
  end

  defp clean_title(html_tree) do
    html_tree
    |> Queries.text()
    |> String.trim()
  end

  defp good_title?(title) do
    length(String.split(title, " ")) >= 4
  end
end
