# al_rtl

Right-to-left language support for [al-folio](https://github.com/alshedivat/al-folio) v1.x. Implements the plugin
proposed in [al-folio#3544](https://github.com/alshedivat/al-folio/issues/3544).

## Install

```ruby
gem "al_rtl", "= 1.0.0"
```

and in `_config.yml` — **both lists, or the plugin is inert**:

```yaml
plugins:
  - al_rtl
```

That is all the configuration most sites need. Direction follows the page's `lang`, falling back to `site.lang`:

```yaml
---
layout: post
title: یک پست نمونه
lang: fa
---
```

Recognised by default: `ar arc az ckb dv fa he ku ps sd ug ur yi`. To narrow or extend that list:

```yaml
al_rtl:
  langs: [fa, ar]
```

## What it does

- Adds `dir="rtl"` and a correct `lang` to `<html>` on RTL pages.
- Loads a small RTL stylesheet, **only** on those pages.
- Provides `{% if_rtl %}…{% endif_rtl %}` and an `al_rtl_direction` filter for layouts that need to branch.

## Differences from the source PR

The 2022 proposal targeted the Bootstrap-era theme, and three things did not port.

**`dir` goes on `<html>`, not a wrapper `div`.** This is the substantive change. Direction on a wrapper leaves
everything outside it — navbar, footer, skip links, scrollbar placement — laid out left-to-right, and it is also what
CSS logical properties and Tailwind's `rtl:` variant key off. Setting it on the root element is what makes the browser's
own bidi handling apply to the whole document.

**`align="right"` is gone.** It was deprecated in HTML 4.01, does nothing under a Tailwind reset, and conflates
alignment with direction — RTL text is right-aligned _because_ of direction, and forcing it breaks centred headings.

**No manual sidebar flipping.** The original swapped the TOC sidebar's column order in Liquid. With `dir` set correctly
the grid mirrors on its own, so that logic is not needed.

One thing the original did not handle: **code and maths stay left-to-right.** Source code, shell transcripts, BibTeX and
rendered equations are LTR content no matter what language surrounds them, and letting them inherit `rtl` reorders
operators and punctuation into nonsense.

## Fonts

No webfont is bundled. The source PR pulled Vazirmatn from Google Fonts for every page, which is a third-party request
and a privacy consideration that should be the site owner's choice. Add one through al-folio's normal font
configuration if you want it.

## Development

```bash
bundle install
bundle exec rake test
npm ci && npm run lint:prettier
```

## License

MIT
