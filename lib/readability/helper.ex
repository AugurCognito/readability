defmodule Readability.Helper do
  @moduledoc """
  Helpers for parsing, updating, and removing HTML tree nodes.

  Operates on LazyHTML tree tuples `{tag, attrs, children}`.
  """

  @type html_tree :: tuple | list

  @doc """
  Change existing tags by selector (tag name match).
  """
  @spec change_tag(html_tree, String.t(), String.t()) :: html_tree
  def change_tag(content, _, _) when is_binary(content), do: content
  def change_tag([], _, _), do: []

  def change_tag([h | t], selector, tag) do
    [change_tag(h, selector, tag) | change_tag(t, selector, tag)]
  end

  def change_tag({tag_name, attrs, inner_tree}, tag_name, tag) do
    {tag, attrs, change_tag(inner_tree, tag_name, tag)}
  end

  def change_tag({tag_name, attrs, html_tree}, selector, tag) do
    {tag_name, attrs, change_tag(html_tree, selector, tag)}
  end

  @doc """
  Remove HTML attributes matching the given filter.

  Filter can be a string (exact match), a regex, or a list of strings.
  """
  @spec remove_attrs(html_tree, String.t() | [String.t()] | Regex.t()) :: html_tree
  def remove_attrs(content, _) when is_binary(content), do: content
  def remove_attrs([], _), do: []

  def remove_attrs([h | t], t_attrs) do
    [remove_attrs(h, t_attrs) | remove_attrs(t, t_attrs)]
  end

  def remove_attrs({tag_name, attrs, inner_tree}, target_attr) do
    reject_fun =
      cond do
        is_binary(target_attr) ->
          fn attr -> elem(attr, 0) == target_attr end

        is_struct(target_attr, Regex) ->
          fn attr -> elem(attr, 0) =~ target_attr end

        is_list(target_attr) ->
          fn attr -> Enum.member?(target_attr, elem(attr, 0)) end

        true ->
          fn attr -> attr end
      end

    {tag_name, Enum.reject(attrs, reject_fun), remove_attrs(inner_tree, target_attr)}
  end

  @doc """
  Removes nodes from the tree where the predicate function returns true.
  """
  @spec remove_tag(html_tree, fun) :: html_tree
  def remove_tag(content, _) when is_binary(content), do: content
  def remove_tag([], _), do: []
  def remove_tag([{:comment, _} | t], fun), do: remove_tag(t, fun)

  def remove_tag([h | t], fun) do
    node = remove_tag(h, fun)

    if node == [] do
      remove_tag(t, fun)
    else
      [node | remove_tag(t, fun)]
    end
  end

  def remove_tag({tag, attrs, inner_tree} = html_tree, fun) do
    if fun.(html_tree) do
      []
    else
      {tag, attrs, remove_tag(inner_tree, fun)}
    end
  end

  @doc """
  Normalizes and parses raw HTML into a tree (list of tuples).

  Performs pre-processing: strips XML declarations, normalizes whitespace,
  converts double `<br>` tags to paragraph breaks, replaces `<font>` with
  `<span>`, then parses via LazyHTML.
  """
  @spec normalize(binary) :: html_tree
  def normalize(raw_html) do
    raw_html
    |> String.replace(Readability.regex(:replace_xml_version), "")
    |> String.replace(Readability.regex(:replace_brs), "</p><p>")
    |> String.replace(Readability.regex(:replace_fonts), "<\\1span>")
    |> String.replace(Readability.regex(:normalize), " ")
    |> LazyHTML.from_document()
    |> LazyHTML.to_tree(skip_whitespace_nodes: true)
    |> remove_tag(fn {tag, _, _} -> is_atom(tag) end)
  end
end
