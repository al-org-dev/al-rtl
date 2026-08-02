# Changelog

## 1.0.0 — 2026-08-02

- Initial release of `al_rtl`, implementing the plugin proposed in
  [alshedivat/al-folio#3544](https://github.com/alshedivat/al-folio/issues/3544) (source PR
  [#946](https://github.com/alshedivat/al-folio/pull/946)).
- Direction is set with `dir` on `<html>` rather than on a wrapper `div`, so page chrome mirrors too and CSS logical
  properties work.
- Detection handles region subtags and casing (`fa-IR`, `FA`), with a per-page `lang` override.
- Code, shell transcripts and rendered maths are held left-to-right inside RTL prose.
