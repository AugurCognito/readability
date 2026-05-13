defmodule Readability.AuthorFinder do
  @moduledoc """
  Extracts author names from HTML tree meta tags.
  """

  alias Readability.Queries

  @type html_tree :: tuple | list

  @doc """
  Extracts author names from meta tags.

  Looks for `<meta name="*author*">` and `<meta property="*author*">` tags.
  Returns a list of author name strings, or an empty list if none found.
  """
  @spec find(html_tree) :: [binary]
  def find(html_tree) do
    case find_by_meta_tag(html_tree) do
      nil -> []
      author_names -> split_author_names(author_names)
    end
  end

  @doc false
  @spec find_by_meta_tag(html_tree) :: binary | nil
  def find_by_meta_tag(html_tree) do
    names =
      html_tree
      |> Queries.find_tag("meta")
      |> Enum.filter(fn {_, attrs, _} ->
        has_author_attr?(attrs, "name") || has_author_attr?(attrs, "property")
      end)
      |> Enum.map(fn {_, attrs, _} ->
        case List.keyfind(attrs, "content", 0) do
          {"content", value} -> String.trim(value)
          _ -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))

    case names do
      [first | _] -> first
      [] -> nil
    end
  end

  defp has_author_attr?(attrs, key) do
    case List.keyfind(attrs, key, 0) do
      {_, value} -> value =~ ~r/author/i
      nil -> false
    end
  end

  defp split_author_names(author_name) do
    author_name
    |> String.split(~r/,\s|\sand\s|by\s/i)
    |> Enum.reject(&(String.length(&1) == 0))
  end
end
