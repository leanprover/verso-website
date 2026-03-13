/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: David Thrane Christiansen
-/
import VersoBlog

import Site

section
open Verso Genre Blog Site Syntax

open Output Html Template Theme in
def theme : Theme := { Theme.default with
  primaryTemplate := do
    return {{
      <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1"/>
          <title>"Verso — Written in Lean, checked by Lean"</title>
          <link rel="icon" type="image/svg+xml" href="/static/favicon.svg"/>
          <link rel="stylesheet" href="/static/style.css"/>
          <link rel="stylesheet" href= "/static/glightbox/css/glightbox.min.css"/>
          <script src="/static/glightbox/js/glightbox.min.js"></script>
          <script defer>
            r!"document.addEventListener('DOMContentLoaded', () => { const lightbox = GLightbox(); });"
          </script>
          {{← builtinHeader }}
        <!-- Privacy-friendly analytics by Plausible -->
        <script async src="https://plausible.io/js/pa--0OdxwGCKX8nhJ0vma6XG.js"></script>
        <script>
          "window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(i){plausible.o=i||{}};
          plausible.init()"
        </script>
        </head>
        <body>
          <header>
            <nav class="navbar">
              <div class="nav-inner">
                <a class="logo" href="/">"Verso"</a>
                <div class="nav-links">
                  <a href="#why-verso">"Why Verso?"</a>
                  <a href="#what-to-build">"Applications"</a>
                  <a href="#showcase">"Built with Verso"</a>
                  <a href="#get-started">"Get Started"</a>
                  <span class="divider">" | "</span>
                  <a href="/doc/latest">"User Manual"</a>
                  <a href="https://github.com/leanprover/verso" aria-label="GitHub" target="_blank">
                    <img src="/static/github.svg" alt="GitHub" width="22" height="22"/>
                  </a>
                </div>
              </div>
            </nav>
          </header>
          <main>
            {{← param "content" }}
          </main>

          <script>
            {{.text false "window.addEventListener('load', () => {\n  if (typeof tippy === 'undefined') return;\n  document.querySelectorAll('.verso-source [data-tooltip]').forEach(el => {\n    el.setAttribute('data-tippy-theme', 'lean');\n  });\n  tippy('.verso-source [data-tooltip]', {\n    content(el) {\n      var raw = el.getAttribute('data-tooltip');\n      if (typeof marked !== 'undefined') {\n        var div = document.createElement('div');\n        div.classList.add('hover-info');\n        div.innerHTML = marked.parse(raw);\n        return div;\n      }\n      return raw;\n    },\n    allowHTML: true,\n    theme: 'lean',\n    placement: 'top',\n    delay: [100, null],\n    appendTo: () => document.body\n  });\n});"}}
          </script>
          <footer>
            <div class="footer-inner">
              <div class="footer-columns">
                <div class="footer-col">
                  <h4>"Get Started"</h4>
                  <a href="https://github.com/leanprover/verso-templates">"Templates"</a>
                  <a href="https://leanprover.zulipchat.com/#narrow/channel/576452-verso">"Community"</a>
                </div>
                <div class="footer-col">
                  <h4>"Documentation"</h4>
                  <a href="/doc/latest">"User Manual"</a>
                  <a href="https://github.com/leanprover/verso">"Source Code"</a>
                </div>
                <div class="footer-col">
                  <h4>"Resources"</h4>
                  <a href="https://lean-lang.org/">"Lean"</a>
                  <a href="https://leanprover.zulipchat.com/">"Zulip"</a>
                  <a href="https://github.com/leanprover/verso">"GitHub"</a>
                </div>
              </div>
              <p class="footer-copy">"© 2026 Lean FRO, LLC"</p>
            </div>
          </footer>
        </body>
      </html>
    }}
  }

def versoSite : Site := site Site.FrontPage /
  static "static" ← "static_files"
  static "netlify.toml" ← "netlify.toml"

def main (args : List String) : IO UInt32 := do
  let remotes ← Verso.Multi.updateRemotes false none (fun _ => pure ())
  blogMain theme versoSite (linkTargets := remotes.remoteTargets) args
