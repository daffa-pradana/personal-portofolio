module ArticlesHelper
  # An article's optional CTA (button_label/button_url) points either at an
  # external URL or at an in-page anchor like "#chat".
  #
  # Anchors are resolved against the landing page rather than left bare,
  # because the sections they target (#chat, #contacts, …) only exist there.
  # A literal "#chat" href works on "/" but is dead on /articles and
  # /articles/:slug, where these same CTAs render. This mirrors what the
  # navbar and footer already do with root_path(anchor:).
  def article_cta_url(article)
    url = article.button_url.to_s

    if url.start_with?("#")
      root_path(anchor: url.delete_prefix("#"))
    else
      url
    end
  end

  # External links open in a new tab; in-page anchors must not, or the
  # smooth-scroll never happens.
  def article_cta_link_options(article)
    if article.button_url.to_s.start_with?("#")
      {}
    else
      { target: "_blank", rel: "noopener noreferrer" }
    end
  end
end
