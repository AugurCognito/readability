defmodule Readability do
  @moduledoc """
  Readability library for extracting and curating articles from raw HTML.

  Uses LazyHTML (Rust NIF) for HTML parsing. Accepts raw HTML strings only —
  does not fetch URLs.

  ## Example

      # Extract article text
      {:ok, text} = Readability.extract(html)

      # Extract title
      title = Readability.extract_title(html)

      # Extract authors
      authors = Readability.extract_authors(html)

      # Extract published date
      datetime = Readability.extract_published_at(html)

      # Extract article tree (for advanced use)
      article_tree = Readability.article(html)
      html_string = Readability.readable_html(article_tree)
  """

  alias Readability.ArticleBuilder
  alias Readability.AuthorFinder
  alias Readability.Helper
  alias Readability.PublishedAtFinder
  alias Readability.TitleFinder

  @default_options [
    retry_length: 250,
    min_text_length: 25,
    remove_unlikely_candidates: true,
    weight_classes: true,
    clean_conditionally: true,
    remove_empty_nodes: true,
    min_image_width: 130,
    min_image_height: 80,
    ignore_image_format: [],
    blacklist: nil,
    whitelist: nil
  ]

  @type html_tree :: tuple | list
  @type options :: list

  # --- Regexes (module attributes, not public functions) ---

  @re_unlikely_candidate ~r/combx|comment|community|disqus|extra|foot|header|hidden|lightbox|modal|menu|meta|nav|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup/i
  @re_ok_maybe_candidate ~r/and|article|body|column|main|shadow/i
  @re_positive ~r/article|body|content|entry|hentry|main|page|pagination|post|text|blog|story/i
  @re_negative ~r/hidden|^hid|combx|comment|com-|contact|foot|footer|footnote|link|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|utility|widget/i
  @re_div_to_p_elements ~r/<(a|blockquote|dl|div|img|ol|p|pre|table|ul)/i
  @re_replace_brs ~r/(<br[^>]*>[ \n\r\t]*){2,}/i
  @re_replace_fonts ~r/<(\/?)font[^>]*>/i
  @re_replace_xml_version ~r/<\?xml.*\?>/i
  @re_normalize ~r/\s{2,}/
  @re_video ~r/\/\/(www\.)?(dailymotion|youtube|youtube-nocookie|player\.vimeo)\.com/i
  @re_protect_attrs ~r/^(?!id|rel|for|summary|title|href|src|alt|srcdoc)/i

  # --- Public API ---

  @doc """
  Extract the main article text from raw HTML.

  Returns `{:ok, text}` with the article body as plain text,
  or `{:error, :no_content}` if no meaningful content was found.
  """
  @spec extract(binary) :: {:ok, binary} | {:error, :no_content}
  def extract(html) when is_binary(html) do
    article_tree = article(html)
    text = readable_text(article_tree)

    if String.length(text) >= @default_options[:min_text_length] do
      {:ok, text}
    else
      {:error, :no_content}
    end
  end

  @doc """
  Extract the article title from raw HTML.

  Checks og:title meta tag first, then falls back to `<title>` tag,
  then to `<h1>` tag.
  """
  @spec extract_title(binary) :: binary | nil
  def extract_title(html) when is_binary(html) do
    tree = Helper.normalize(html)

    case TitleFinder.title(tree) do
      "" -> nil
      title -> title
    end
  end

  @doc """
  Extract article authors from raw HTML.

  Looks for author meta tags (`name=author`, `property=*author`).
  """
  @spec extract_authors(binary) :: [binary]
  def extract_authors(html) when is_binary(html) do
    html
    |> Helper.normalize()
    |> AuthorFinder.find()
  end

  @doc """
  Extract the publication date from raw HTML.

  Checks meta tags, `<time>` elements, and `data-datetime` attributes.
  """
  @spec extract_published_at(binary) :: DateTime.t() | Date.t() | nil
  def extract_published_at(html) when is_binary(html) do
    html
    |> Helper.normalize()
    |> PublishedAtFinder.find()
  end

  @doc """
  Extract the article tree from raw HTML.

  Uses content scoring, class/id weighting, link density analysis, and
  retry heuristics to find the most likely article content.

  Returns an HTML tree suitable for `readable_html/1` or `readable_text/1`.
  """
  @spec article(binary, options) :: html_tree
  def article(html, opts \\ []) do
    opts = Keyword.merge(@default_options, opts)

    html
    |> Helper.normalize()
    |> ArticleBuilder.build(opts)
  end

  @doc """
  Returns cleaned HTML from an article tree (strips non-essential attributes).
  """
  @spec readable_html(html_tree) :: binary
  def readable_html(html_tree) do
    html_tree
    |> Helper.remove_attrs(regex(:protect_attrs))
    |> raw_html()
  end

  @doc """
  Returns only text from an article tree.
  """
  @spec readable_text(html_tree) :: binary
  def readable_text(html_tree) do
    tags_to_br = ~r/<\/(p|div|article|h\d)/i
    html_str = raw_html(html_tree)

    tags_to_br
    |> Regex.replace(html_str, &"\n#{&1}")
    |> then(fn str ->
      str
      |> LazyHTML.from_fragment()
      |> LazyHTML.text()
    end)
    |> String.trim()
  end

  @doc """
  Returns raw HTML from an HTML tree.
  """
  @spec raw_html(html_tree) :: binary
  def raw_html(html_tree) do
    html_tree
    |> List.wrap()
    |> LazyHTML.Tree.to_html()
  end

  @doc """
  Access regex patterns used by the readability algorithm.

  These are used internally by sub-modules for scoring, cleaning,
  and normalization.
  """
  @spec regex(atom) :: Regex.t() | nil
  def regex(:unlikely_candidate), do: @re_unlikely_candidate
  def regex(:ok_maybe_its_a_candidate), do: @re_ok_maybe_candidate
  def regex(:positive), do: @re_positive
  def regex(:negative), do: @re_negative
  def regex(:div_to_p_elements), do: @re_div_to_p_elements
  def regex(:replace_brs), do: @re_replace_brs
  def regex(:replace_fonts), do: @re_replace_fonts
  def regex(:replace_xml_version), do: @re_replace_xml_version
  def regex(:normalize), do: @re_normalize
  def regex(:video), do: @re_video
  def regex(:protect_attrs), do: @re_protect_attrs
  def regex(_key), do: nil

  @doc false
  @spec default_options() :: options
  def default_options, do: @default_options
end
