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
          <link rel="stylesheet" href="/static/style.css"/>
          <link rel="stylesheet" href= "/static/glightbox/css/glightbox.min.css"/>
          <script src="/static/glightbox/js/glightbox.min.js"></script>
          <script defer>
            r!"document.addEventListener('DOMContentLoaded', () => { const lightbox = GLightbox(); });"
          </script>
          {{← builtinHeader }}
        </head>
        <body>
          <header>
            <nav class="navbar">
              <div class="nav-inner">
                <a class="logo" href="/">"Verso"</a>
                <div class="nav-links">
                  <a href="https://verso-user-manual.netlify.app/">"User Manual"</a>
                  <a href="https://github.com/leanprover/verso">"GitHub"</a>
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
              <a href="https://github.com/leanprover/verso">"GitHub"</a>
              " · "
              <a href="https://verso-user-manual.netlify.app/">"User Manual"</a>
              " · "
              <a href="https://leanprover.zulipchat.com/">"Zulip"</a>
            </div>
          </footer>
        </body>
      </html>
    }}
  }

def versoSite : Site := site Site.FrontPage /
  static "static" ← "static_files"

def main (args : List String) : IO UInt32 := do
  let remotes ← Verso.Multi.updateRemotes false none (fun _ => pure ())
  blogMain theme versoSite (linkTargets := remotes.remoteTargets) args
