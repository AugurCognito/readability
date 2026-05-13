defmodule Readability.Summary do
  @moduledoc """
  Struct holding extracted article data.
  """

  @type t :: %__MODULE__{
          title: binary | nil,
          authors: [binary] | nil,
          article_html: binary | nil,
          article_text: binary | nil,
          published_at: DateTime.t() | Date.t() | nil
        }

  defstruct title: nil, authors: [], article_html: nil, article_text: nil, published_at: nil
end
