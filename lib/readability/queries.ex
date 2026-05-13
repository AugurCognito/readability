defmodule Readability.Queries do
  @moduledoc """
  Optimized utilities for querying HTML tree structures.

  Operates on LazyHTML tree tuples `{tag, attrs, children}`.
  """

  @type html_tree :: tuple | list

  @doc """
  Annotates tree nodes with cached `:text_length` and `:commas` in their
  attributes for faster repeated lookups during scoring.
  """
  @spec cache_stats_in_attributes(html_tree) :: html_tree
  def cache_stats_in_attributes(tree) do
    LazyHTML.Tree.postwalk(tree, fn
      {tag, attrs, nodes} = node ->
        attrs =
          if Keyword.has_key?(attrs, :text_length) do
            attrs
          else
            Keyword.put(attrs, :text_length, text_length(node))
          end

        attrs =
          if Keyword.has_key?(attrs, :commas) do
            attrs
          else
            Keyword.put(attrs, :commas, count_character(node, ","))
          end

        {tag, attrs, nodes}

      other ->
        other
    end)
  end

  @doc """
  Removes cached stats from tree attributes.
  """
  @spec clear_stats_from_attributes(html_tree) :: html_tree
  def clear_stats_from_attributes(tree) do
    LazyHTML.Tree.postwalk(tree, fn
      {tag, attrs, nodes} ->
        {tag, Keyword.drop(attrs, [:text_length, :commas]), nodes}

      other ->
        other
    end)
  end

  @doc """
  Counts the total text length in the tree.
  """
  @spec text_length(html_tree) :: number
  def text_length(text) when is_binary(text), do: String.length(text)
  def text_length(nodes) when is_list(nodes), do: Enum.reduce(nodes, 0, &(&2 + text_length(&1)))
  def text_length({:comment, _}), do: 0
  def text_length({"br", _, _}), do: 1

  def text_length({_tag, attrs, nodes}) do
    Keyword.get_lazy(attrs, :text_length, fn -> text_length(nodes) end)
  end

  @doc """
  Counts occurrences of a character in the tree's text content.
  """
  @spec count_character(html_tree, binary) :: number
  def count_character(<<v::utf8, rest::binary>>, <<v::utf8>> = char) do
    1 + count_character(rest, char)
  end

  def count_character(<<_::utf8, rest::binary>>, char) do
    count_character(rest, char)
  end

  def count_character(nodes, char) when is_list(nodes) do
    Enum.reduce(nodes, 0, &(&2 + count_character(&1, char)))
  end

  def count_character({_tag, attrs, nodes}, ",") do
    Keyword.get_lazy(attrs, :commas, fn -> count_character(nodes, ",") end)
  end

  def count_character({_tag, _attrs, nodes}, char), do: count_character(nodes, char)
  def count_character(_node, _char), do: 0

  @doc """
  Finds all nodes with the given tag name in the tree.
  """
  @spec find_tag(html_tree, binary) :: list
  def find_tag(html_tree, tag), do: html_tree |> find_tag_internal(tag) |> List.flatten()

  @doc false
  def find_tag_internal(nodes, tag) when is_list(nodes),
    do: Enum.map(nodes, &find_tag_internal(&1, tag))

  def find_tag_internal({tag, _, children} = node, tag),
    do: [node | find_tag_internal(children, tag)]

  def find_tag_internal({_, _, children}, tag), do: find_tag_internal(children, tag)
  def find_tag_internal(_, _), do: []

  @doc """
  Extracts the text content of the tree as a single string.
  """
  @spec text(html_tree) :: binary
  def text(nodes) when is_list(nodes), do: Enum.map_join(nodes, &text/1)
  def text({_tag, _attrs, children}), do: text(children)
  def text(text) when is_binary(text), do: text
  def text({:comment, _}), do: ""
  def text(_), do: ""
end
