defmodule Readability.Candidate do
  @moduledoc """
  A scored candidate node that may contain the article content.
  """
  defstruct html_tree: {}, score: 0, tree_depth: 0
end
