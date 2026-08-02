# frozen_string_literal: true

require_relative "test_helper"

class RtlTest < Minitest::Test
  include RenderHelpers

  # --- language detection -------------------------------------------------

  def test_detects_the_shipped_rtl_languages
    %w[ar fa he ur ps sd ug yi dv ku ckb az arc].each do |code|
      assert AlRtl.rtl?(site_with, { "lang" => code }), "#{code} should be RTL"
    end
  end

  def test_ltr_languages_are_not_rtl
    %w[en fr de ja zh ru].each do |code|
      refute AlRtl.rtl?(site_with, { "lang" => code }), "#{code} should not be RTL"
    end
  end

  def test_region_subtags_and_casing_are_handled
    # "fa-IR", "fa_IR" and "FA" all mean Persian. Comparing the raw string would
    # silently render these left-to-right.
    assert AlRtl.rtl?(site_with, { "lang" => "fa-IR" })
    assert AlRtl.rtl?(site_with, { "lang" => "fa_IR" })
    assert AlRtl.rtl?(site_with, { "lang" => "FA" })
    assert AlRtl.rtl?(site_with, { "lang" => "  ar-EG " })
  end

  def test_page_language_overrides_the_site_language
    # A single Persian post on an English site must render RTL.
    assert AlRtl.rtl?(site_with("lang" => "en"), { "lang" => "fa" })
    # ...and an English post on a Persian site must not.
    refute AlRtl.rtl?(site_with("lang" => "fa"), { "lang" => "en" })
  end

  def test_falls_back_to_the_site_language
    assert AlRtl.rtl?(site_with("lang" => "he"), {})
    assert AlRtl.rtl?(site_with("lang" => "he"), { "lang" => "" })
    refute AlRtl.rtl?(site_with("lang" => "en"), {})
  end

  def test_no_language_anywhere_is_not_rtl
    refute AlRtl.rtl?(site_with, {})
    refute AlRtl.rtl?(nil, nil)
  end

  def test_language_list_is_configurable
    site = site_with("al_rtl" => { "langs" => %w[fa] })

    assert AlRtl.rtl?(site, { "lang" => "fa" })
    # Overriding the list replaces it, so Hebrew is no longer detected.
    refute AlRtl.rtl?(site, { "lang" => "he" })
  end

  def test_empty_configured_list_falls_back_to_defaults
    # An empty list is almost certainly a config accident; treating it as "no RTL
    # languages" would disable the plugin silently.
    site = site_with("al_rtl" => { "langs" => [] })

    assert AlRtl.rtl?(site, { "lang" => "ar" })
  end

  # --- html attributes ----------------------------------------------------

  def test_html_attrs_sets_dir_on_rtl_pages
    html = render("{% al_rtl_html_attrs %}", site: site_with, page: { "lang" => "fa" })

    assert_includes html, 'dir="rtl"'
    assert_includes html, 'lang="fa"'
  end

  def test_html_attrs_omits_dir_on_ltr_pages
    html = render("{% al_rtl_html_attrs %}", site: site_with("lang" => "en"), page: {})

    refute_includes html, "dir="
    assert_includes html, 'lang="en"'
  end

  def test_html_attrs_preserves_region_subtag_in_lang
    # Direction is decided on the primary subtag, but `lang` should keep the full
    # tag: "fa-IR" carries real locale information for spellcheckers and TTS.
    html = render("{% al_rtl_html_attrs %}", site: site_with, page: { "lang" => "fa-IR" })

    assert_includes html, 'lang="fa-IR"'
    assert_includes html, 'dir="rtl"'
  end

  def test_html_attrs_is_empty_without_any_language
    assert_equal "", render("{% al_rtl_html_attrs %}", site: site_with, page: {})
  end

  def test_html_attrs_escapes_its_value
    html = render("{% al_rtl_html_attrs %}", site: site_with, page: { "lang" => '"><script>' })

    refute_includes html, "<script>"
  end

  # --- styles -------------------------------------------------------------

  def test_stylesheet_only_on_rtl_pages
    assert_equal "", render("{% al_rtl_styles %}", site: site_with("lang" => "en"), page: {})
    assert_includes render("{% al_rtl_styles %}", site: site_with, page: { "lang" => "ar" }),
                    "/al-folio/assets/al_rtl/css/rtl.css"
  end

  # --- block and filter ---------------------------------------------------

  def test_if_rtl_block
    template = "{% if_rtl %}RTL{% endif_rtl %}"

    assert_equal "RTL", render(template, site: site_with, page: { "lang" => "he" })
    assert_equal "", render(template, site: site_with, page: { "lang" => "en" })
  end

  def test_direction_filter
    assert_equal "rtl", render("{{ 'fa' | al_rtl_direction }}", site: site_with, page: {})
    assert_equal "ltr", render("{{ 'en' | al_rtl_direction }}", site: site_with, page: {})
  end

  # --- shipped stylesheet -------------------------------------------------

  def test_stylesheet_is_scoped_so_it_cannot_affect_ltr_pages
    css = File.read(ROOT.join("lib/assets/al_rtl/css/rtl.css"))
    rules = css.gsub(%r{/\*.*?\*/}m, "").scan(/^\s*([^@{}]+)\{/).flatten

    refute_empty rules
    rules.each do |selector|
      assert_includes selector, '[dir="rtl"]', "unscoped rule would leak onto LTR pages: #{selector.strip}"
    end
  end

  def test_code_and_math_stay_left_to_right
    # Source code and rendered maths are LTR content whatever the prose is;
    # inheriting rtl reorders operators and punctuation into nonsense.
    css = File.read(ROOT.join("lib/assets/al_rtl/css/rtl.css"))

    assert_match(/\[dir="rtl"\]\s+pre/, css)
    assert_includes css, "direction: ltr"
  end

  # --- regression: Jekyll hands us a Drop, not a Hash ---------------------

  def test_reads_front_matter_from_a_drop_not_just_a_hash
    # Jekyll sets registers[:page] to a DocumentDrop. An earlier version tested
    # `page.is_a?(Hash)`, which made every real page fall back to site.lang and
    # silently disabled the plugin site-wide, while these tests passed.
    assert AlRtl.rtl?(site_with("lang" => "en"), DropLike.new("lang" => "fa"))
    refute AlRtl.rtl?(site_with("lang" => "en"), DropLike.new("lang" => "de"))
  end

  def test_html_attrs_uses_drop_front_matter
    html = render("{% al_rtl_html_attrs %}", site: site_with("lang" => "en"), page: DropLike.new("lang" => "he"))

    assert_includes html, 'dir="rtl"'
    assert_includes html, 'lang="he"'
  end

  # --- regression: assets must land where the tags point ------------------

  def test_assets_are_published_under_slash_assets
    # Jekyll writes a StaticFile to <dest>/<dir>/<name>. Basing it on the gem
    # root instead of lib/ puts everything under /lib/assets/..., while every
    # tag emits /assets/... — a 404 that only shows up in a real build.
    entries = AlRtl.asset_entries

    refute_empty entries
    entries.each do |relative_dir, name|
      assert relative_dir.start_with?("assets/al_rtl"),
             "#{relative_dir}/#{name} would be published outside /assets/al_rtl"
      refute_includes relative_dir, "lib/"
    end
  end

  def test_every_referenced_asset_is_actually_published
    published = AlRtl.asset_entries.map { |dir, name| "/#{dir}/#{name}" }

    assert_includes published, "/assets/al_rtl/css/rtl.css"
  end
end
