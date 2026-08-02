# frozen_string_literal: true

require "cgi"
require "jekyll"
require "liquid"
require_relative "al_rtl/version"

# Right-to-left language support.
#
# Direction is set with `dir` on the <html> element rather than on a wrapper
# div, which is what the original v0.x proposal did. That matters for more than
# tidiness: `dir` on <html> is what makes CSS logical properties, the `rtl:`
# Tailwind variant, form controls, scrollbar placement and the browser's own
# bidi algorithm behave. A wrapper div leaves the chrome outside it — navbar,
# footer, skip links — still laid out left-to-right.
#
# It also drops the `align="right"` the original used. That attribute was
# deprecated in HTML 4.01, does nothing in modern engines under a Tailwind
# reset, and conflates alignment with direction: RTL text is right-aligned as a
# *consequence* of direction, and forcing it breaks centred headings.
module AlRtl
  PLUGIN_ROOT = File.expand_path("..", __dir__)
  # Jekyll writes a StaticFile to <dest>/<dir>/<name>, where <dir> is relative
  # to the base below. That base must be lib/, not the gem root, or assets land
  # at /lib/assets/... while every tag in this file points at /assets/... .
  LIB_ROOT = __dir__
  ASSETS_ROOT = File.join(LIB_ROOT, "assets")

  # ISO 639 codes for the scripts written right-to-left. Overridable via
  # `al_rtl.langs`, but shipping a default means most sites configure nothing.
  DEFAULT_LANGS = %w[ar arc az ckb dv fa he ku ps sd ug ur yi].freeze

  class PluginStaticFile < Jekyll::StaticFile; end

  module_function

  def config(site)
    return {} unless site

    site.config["al_rtl"] || {}
  end

  def languages(site)
    configured = config(site)["langs"]
    list = configured.is_a?(Array) && !configured.empty? ? configured : DEFAULT_LANGS
    list.map { |code| normalize(code) }
  end

  # "fa-IR" and "FA" both mean Persian. Compare on the primary subtag, lowercased,
  # or a site that writes the region form gets silently left-to-right.
  def normalize(code)
    code.to_s.strip.downcase.split(/[-_]/).first.to_s
  end

  # The page's own `lang` wins over the site default, so a single RTL post on an
  # otherwise English site renders correctly.
  #
  # Reads through `[]` rather than testing for Hash: at render time Jekyll hands
  # `registers[:page]` a Drop (Jekyll::Drops::DocumentDrop), not a Hash, so an
  # `is_a?(Hash)` guard silently discards every page's front matter and falls
  # back to the site language.
  def page_value(page, key)
    return nil unless page.respond_to?(:[])

    page[key]
  rescue StandardError
    nil
  end

  def language_for(site, page)
    page_lang = page_value(page, "lang")
    return page_lang unless page_lang.to_s.strip.empty?

    site&.config&.[]("lang")
  end

  def rtl?(site, page)
    lang = normalize(language_for(site, page))
    return false if lang.empty?

    languages(site).include?(lang)
  end

  # Emits the raw language tag for the `lang` attribute, preserving any region
  # subtag ("fa-IR"), since that is legitimate content for `lang`.
  def language_tag(site, page)
    language_for(site, page).to_s.strip
  end

  # [relative_dir, filename] for everything this gem publishes. Exposed so the
  # destination path can be asserted without booting a full Jekyll site.
  def asset_entries
    Dir.glob(File.join(ASSETS_ROOT, "**", "*")).sort.reject { |p| File.directory?(p) }.map do |source_path|
      [File.dirname(source_path).sub("#{LIB_ROOT}/", ""), File.basename(source_path)]
    end
  end

  class AssetsGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      Dir.glob(File.join(ASSETS_ROOT, "**", "*")).sort.each do |source_path|
        next if File.directory?(source_path)

        relative_dir = File.dirname(source_path).sub("#{LIB_ROOT}/", "")
        site.static_files << PluginStaticFile.new(site, LIB_ROOT, relative_dir, File.basename(source_path))
      end
    end
  end

  # {% al_rtl_html_attrs %} — goes inside the <html> tag.
  #
  # Always emits a `lang`, and adds `dir="rtl"` only for RTL pages. Emitting
  # `dir="ltr"` explicitly would be harmless but noisy; the default is already
  # ltr.
  class HtmlAttrsTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      page = context.registers[:page]

      attributes = []
      tag = AlRtl.language_tag(site, page)
      attributes << %(lang="#{CGI.escapeHTML(tag)}") unless tag.empty?
      attributes << %(dir="rtl") if AlRtl.rtl?(site, page)
      attributes.join(" ")
    end
  end

  # {% al_rtl_styles %} — the RTL stylesheet, only on RTL pages.
  class StylesTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      page = context.registers[:page]
      return "" unless AlRtl.rtl?(site, page)

      baseurl = site.config["baseurl"] || ""
      %(<link rel="stylesheet" href="#{baseurl}/assets/al_rtl/css/rtl.css">\n)
    end
  end

  # {% if_rtl %}…{% endif_rtl %} for layouts that need to branch.
  class IfRtlBlock < Liquid::Block
    def render(context)
      return "" unless AlRtl.rtl?(context.registers[:site], context.registers[:page])

      super
    end
  end

  module Filters
    # `{{ page.lang | al_rtl_direction }}` -> "rtl" / "ltr"
    def al_rtl_direction(value)
      AlRtl.languages(@context.registers[:site]).include?(AlRtl.normalize(value)) ? "rtl" : "ltr"
    end
  end
end

Liquid::Template.register_tag("al_rtl_html_attrs", AlRtl::HtmlAttrsTag)
Liquid::Template.register_tag("al_rtl_styles", AlRtl::StylesTag)
Liquid::Template.register_tag("if_rtl", AlRtl::IfRtlBlock)
Liquid::Template.register_filter(AlRtl::Filters)
