import VersoBlog
import Site.Meta
import Site.VersoHL
import Site.Tactic

open Verso Genre Doc Elab
open Verso.Output Html
open Lean
open Blog hiding lean
open Site

inline_component Inline.kbd (keySequence : Array String) where
  cssFiles := #[
    ("kbd.css",
"kbd {
  font-family: ui-monospace, monospace;
  font-size: 0.85em;
  padding: 0.15em 0.4em;
  border: 1px solid #aaa;
  border-bottom-width: 2px;
  border-radius: 3px;
  background: #f5f5f5;
}"
    )
  ]
  toHtml _ _ _ _ := do
    let key (k : String) :=
      {{<kbd>{{k}}</kbd>}}
    match keySequence with
    | #[k] => return key k
    | ks =>
      return ks.map key

/--
A keyboard shortcut.

All parameters should be code elements.
-/
@[role]
def kbd : RoleExpanderOf NoArgs
  | {}, inlines => do
    let code ← codeSeq inlines
    if code.size < 1 then throwError "Expected one or more code inlines"
    let keys := code.map (·.getString)
    `(Inline.kbd $(quote keys) #[])

#doc (Page) "Integration" =>

Press {kbd}[`\`] followed by a Unicode abbreviation to enter extra characters.
Or {kbd}[`Ctrl` `C`] to copy and {kbd}[`Ctrl` `V`] to paste.
