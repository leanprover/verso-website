/-
Tactic role: links tactic names to the Lean Language Reference.
Uses MultiVerso cross-referencing to resolve URLs at traversal time.
-/
import VersoBlog
import MultiVerso
import VersoManual.Basic

open Verso Doc Elab
open Verso.Output Html
open Lean
open Verso.Multi
open Verso.Genre.Blog

namespace Site

private def tacticDomain : Name := `Verso.Genre.Manual.doc.tactic

/-- Look up a tactic by user-facing name in the remote xref data, returning a URL. -/
def findTacticUrl (remotes : AllRemotes) (tacticName : String) : Option String := Id.run do
  for (_, remote) in remotes.allRemotes do
    if let some domain := remote.domains[tacticDomain]? then
      for (_, objects) in domain.contents do
        for obj in objects do
          let userName := obj.data.getObjValAs? String "userName" |>.toOption
          if userName == some tacticName then
            return some (RemoteLink.link obj.link)
  return none

inline_component tacticRef (name : String) where
  traverse := fun json _contents => do
    let some name := (json.getArr?.toOption.bind (·[0]?) |>.bind (·.getStr?.toOption))
      | return none
    let remotes := (← get).remoteContent
    if let some url := findTacticUrl remotes name then
      let html : Output.Html :=
        {{ <code class="hl lean"><a href={{url}}><span class="keyword">{{name}}</span></a></code> }}
      return some (Inline.other (InlineExt.blob html) #[])
    else
      return none
  toHtml _id _json goI contents := do
    pure {{ <code class="hl lean"><span class="keyword">{{← contents.mapM goI}}</span></code> }}

/-- Extract text from inline code syntax. -/
private def getCodeText (stxs : TSyntaxArray `inline) : Option String := do
  let stx ← stxs[0]?
  let raw := stx.raw
  guard (raw.getKind == ``Lean.Doc.Syntax.code)
  raw.getArg 1 |>.isStrLit?

@[role]
def tactic : RoleExpanderOf Unit
  | (), stxs => do
    let some name := getCodeText stxs
      | throwError "tactic role expects inline code content, e.g. \{tactic}`simp`"
    let contents ← stxs.mapM elabInline
    ``(tacticRef $(quote name) #[$contents,*])

end Site
