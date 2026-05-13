defmodule Readability.PublishedAtFinder do
  @moduledoc """
  Extracts the publication date from HTML tree.

  Tries multiple strategies: meta tags, `<time>` elements, and
  `data-datetime` attributes.
  """

  alias Readability.Queries

  @type html_tree :: tuple | list

  @strategies [:meta_tag, :time_element, :data_attribute]

  @doc """
  Extracts the publication date from the HTML tree.

  Returns a `DateTime`, `Date`, or `nil`.
  """
  @spec find(html_tree) :: DateTime.t() | Date.t() | nil
  def find(html_tree) do
    case Enum.find_value(@strategies, &strategy(&1, html_tree)) do
      nil -> nil
      value -> parse(value)
    end
  end

  defp strategy(:meta_tag, html_tree) do
    html_tree
    |> Queries.find_tag("meta")
    |> Enum.filter(fn {_, attrs, _} ->
      case List.keyfind(attrs, "property", 0) do
        {"property", prop} -> prop in ["article:published_time", "article:published"]
        _ -> false
      end
    end)
    |> Enum.find_value(fn {_, attrs, _} ->
      case List.keyfind(attrs, "content", 0) do
        {"content", value} -> String.trim(value)
        _ -> nil
      end
    end)
  end

  defp strategy(:time_element, html_tree) do
    html_tree
    |> Queries.find_tag("time")
    |> Enum.find_value(fn {_, attrs, _} ->
      case List.keyfind(attrs, "datetime", 0) do
        {"datetime", value} -> String.trim(value)
        _ -> nil
      end
    end)
  end

  defp strategy(:data_attribute, html_tree) do
    html_tree
    |> find_nodes_with_attr("data-datetime")
    |> Enum.find_value(fn {_, attrs, _} ->
      case List.keyfind(attrs, "data-datetime", 0) do
        {"data-datetime", value} -> String.trim(value)
        _ -> nil
      end
    end)
  end

  defp find_nodes_with_attr(tree, attr_name) do
    LazyHTML.Tree.prereduce(tree, [], fn
      {_tag, attrs, _children} = node, acc ->
        if List.keyfind(attrs, attr_name, 0) do
          [node | acc]
        else
          acc
        end

      _, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp parse(value) do
    parse_datetime(value) || parse_date(value)
  end

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
