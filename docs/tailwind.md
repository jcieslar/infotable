# Tailwind CSS Setup for InfoTable

InfoTable **requires** the `tailwindcss-rails` gem (Tailwind CSS v4). Tailwind only generates the classes it finds in files it scans, so it has to scan the gem's views and formatters.

## How it works

The gem ships `app/assets/tailwind/infotable/engine.css`, the entry point `tailwindcss-rails` looks for in Rails engines:

```css
@source "../../../views/infotable";
@source "../../../../lib/infotable/formatters";
@source "../../javascripts/infotable";
```

On every `tailwindcss:build` / `tailwindcss:watch`, `tailwindcss-rails` writes `app/assets/builds/tailwind/infotable.css`, which imports that file. Your Tailwind entry file imports the generated one:

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";
@import "../builds/tailwind/infotable";
```

The `@source` paths are relative to the gem, so this works the same in development, Docker, CI and production, for any way of installing the gem (RubyGems, `path:`, `git:`, vendored). There is nothing to generate or commit.

## Installation

`rails generate infotable:install` adds the import line above. To do it by hand, add it after `@import "tailwindcss";` and build:

```bash
rails tailwindcss:build
```

## Troubleshooting

**Styles missing (no spacing, spinner, drawer, ...)**

1. Check the import exists:
   ```bash
   grep -r "builds/tailwind/infotable" app/assets/
   ```
2. Rebuild, which also regenerates `app/assets/builds/tailwind/infotable.css`:
   ```bash
   rails tailwindcss:build
   ```
3. Check that your layout loads the stylesheet:
   ```erb
   <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
   ```

**Upgrading from 0.x:** delete `app/assets/stylesheets/infotable.css(.erb)` and `app/assets/tailwind/infotable.css(.erb)`, replace `@import './infotable';` with `@import "../builds/tailwind/infotable";`, and drop the `infotable.css` entries from `.gitignore`.
