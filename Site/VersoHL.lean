/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: David Thrane Christiansen
-/
/-
Verso markup syntax highlighting for the Verso website.

Parses Verso markup and renders it as syntax-highlighted HTML,
colorizing based on the syntax tree produced by the Verso parser.

Lean code blocks within the markup are elaborated in the current
module context.
-/
import VersoBlog
import Verso.Parser
import Verso.Output.Html
import Lean.Elab.Command
import SubVerso.Highlighting

open Verso Doc Elab
open Verso.Output Html
open Lean
open Lean.Elab
open Verso.SyntaxUtils
open Lean.Doc (VersoCodeBlock VersoInline VersoBlock InlineView BlockView ArgView)
open SubVerso.Highlighting

namespace Site

/--
Extracts the contents of the code elements in a sequence of inline elements, discarding whitespace.

Logs an error if there are non-code elements.
-/
def codeSeq [Monad m] [MonadLog m] [AddMessageContext m] [MonadOptions m] [MonadError m] (xs : Array VersoInline) : m (Array String) := do
  xs.filterMapM fun i => do
    match InlineView.of i with
    | some (.code v) => return some v.getVersoCode
    | some (.text v) =>
      unless v.getVersoText.all Char.isWhitespace do logErrorAt i "Expected code"
      return none
    | _ =>
      logErrorAt i "Expected code"
      return none

/-- Elaborate Lean source code as commands and return SubVerso-highlighted output. -/
private def elabAndHighlightLean («show» : Bool) (src : VersoCodeBlock) : DocElabM (TSyntax `term) := withoutAsync do
  let scope : Command.Scope := {
    header := "",
    opts := pp.tagAppFns.set (Elab.async.set (← getOptions) false) true,
    currNamespace := ← getCurrNamespace,
    openDecls := ← getOpenDecls
  }
  let srcStr := (← getFileMap).source
  let pos := src.raw.getPos!
  let pos' := src.raw.getTailPos? |>.getD srcStr.rawEndPos
  let pos' := if pos' > srcStr.rawEndPos then srcStr.rawEndPos else pos'
  have : pos' ≤ srcStr.rawEndPos := by grind
  let ictx := Parser.mkInputContext srcStr (← getFileName) (endPos := pos') (endPos_valid := by grind)
  let cctx : Command.Context := {
    fileName := ← getFileName,
    fileMap := (← getFileMap)
    snap? := none,
    cancelTk? := none
  }

  let mut cmdState : Command.State := {
    env := ← getEnv,
    maxRecDepth := ← MonadRecDepth.getMaxRecDepth,
    scopes := [scope]
  }
  let mut pstate : Parser.ModuleParserState := { pos, hasLeading := false }
  let mut cmds := #[]

  repeat
    let s := cmdState.scopes.head!
    let pmctx := {
      env := cmdState.env, options := s.opts,
      currNamespace := s.currNamespace, openDecls := s.openDecls
    }
    let (cmd, ps', messages) := Parser.parseCommand ictx pmctx pstate cmdState.messages
    cmds := cmds.push cmd
    pstate := ps'
    cmdState := { cmdState with messages := messages }

    let (_, cmdState') ←
      match (← liftM <| IO.FS.withIsolatedStreams <| EIO.toIO' <|
        (Command.elabCommand cmd |>.run cctx).run cmdState) with
      | (_, .error e) => Lean.logError e.toMessageData; pure ("", cmdState)
      | (output, .ok ((), cmdState')) => pure (output, cmdState')
    cmdState := cmdState'

    if Parser.isTerminalCommand cmd then break

  -- Report errors
  for msg in cmdState.messages.toArray do
    if msg.severity == .error then logMessage msg

  -- Highlight using SubVerso
  let origEnv ← getEnv
  let origInfoState ← getInfoState
  let mut hls := Highlighted.empty
  try
    setInfoState cmdState.infoState
    setEnv cmdState.env
    let msgs := cmdState.messages.toArray.filter (!·.isSilent)
    for cmd in cmds do
      hls := hls ++ (← highlight cmd msgs cmdState.infoState.trees)
  finally
    setInfoState origInfoState
    setEnv origEnv

  -- Keep the environment changes so later code blocks see earlier definitions
  setEnv cmdState.env
  for t in cmdState.infoState.trees do pushInfoTree t

  if «show» then
    let optsStx ← ``(Verso.Genre.Blog.CodeOpts.mk $(quote `anonymous) true)
    ``(Block.other (Verso.Genre.Blog.BlockExt.highlightedCode $optsStx $(quote hls))
      #[Block.code $(quote <| pos.extract srcStr pos')])
  else
    ``(Block.empty)

/-- Collect CustomHover entries from an info tree. -/
private partial def collectCustomHovers (tree : Lean.Elab.InfoTree) :
    Array (String.Pos.Raw × String) := Id.run do
  match tree with
  | .context _ t => collectCustomHovers t
  | .node info children =>
    let mut result := #[]
    match info with
    | .ofCustomInfo ⟨stx, data⟩ =>
      if let some hover := data.get? Verso.Hover.CustomHover then
        if let some pos := stx.getPos? then
          result := result.push (pos, hover.markedString)
    | _ => pure ()
    for child in children do
      result := result ++ collectCustomHovers child
    result
  | .hole _ => #[]

/--
Parses Verso markup source, render it as syntax-highlighted HTML, and
elaborate the blocks so the rendered output appears after the source.
-/
def highlightVersoSource (src : VersoCodeBlock) : DocElabM (TSyntax `term) := do
  let stx ← parseStrLitWith (Verso.Parser.document {}) src

  -- Elaborate the blocks for rendered output, tracking new info tree entries
  let numTreesBefore := (← getInfoState).trees.size
  let mut outputBlocks : Array (TSyntax `term) := #[]
  for b in stx.getArgs do
    outputBlocks := outputBlocks.push (← elabBlock ⟨b⟩)
  -- Extract CustomHover entries added during elaboration
  let infoState ← getInfoState
  let mut hoverMap : Std.HashMap String.Pos.Raw String := {}
  for i in [numTreesBefore:infoState.trees.size] do
    for entry in collectCustomHovers infoState.trees[i]! do
      hoverMap := hoverMap.insert entry.1 entry.2
  let highlighted : Output.Html := stx.reprint.getD ""
  let sourceHtml := {{ <pre class="verso-source"><code>{{highlighted}}</code></pre> }}
  let blobId := mkIdent ``Verso.Genre.Blog.BlockExt.blob
  let sourceBlock ← ``(Block.other ($blobId $(quote sourceHtml)) #[])
  let sourcePanel ←
    ``(Block.other (Verso.Genre.Blog.BlockExt.htmlDiv "verso-source-panel") #[$sourceBlock])
  let outputPanel ←
    ``(Block.other (Verso.Genre.Blog.BlockExt.htmlDiv "verso-output-panel")
      #[$[$outputBlocks],*])
  ``(Block.other (Verso.Genre.Blog.BlockExt.htmlDiv "verso-demo") #[$sourcePanel, $outputPanel])
end Site

open Site
open Verso.Genre.Blog
open ArgParse

structure TheoremArgs where
  name : String

section
variable {m} [Monad m] [MonadError m]

instance : FromArgs TheoremArgs m where
  fromArgs := TheoremArgs.mk <$> .positional `name .string "the theorem name"
end

block_component theoremC (name : String) where
  toHtml _ _ _ go contents := do
    return html%{
      <div class="theorem"><div class="theorem-name">{name}</div>{← contents.mapM go}</div>
    }

/--
Indicates a named theorem.
-/
@[directive]
def «theorem» : DirectiveExpanderOf TheoremArgs
  | { name }, blocks => do
    ``(theoremC $(quote name) #[$(← blocks.mapM elabBlock),*])

structure LeanArgs where
  «show» : Bool

instance : ArgParse.FromArgs LeanArgs m where
  fromArgs := LeanArgs.mk <$> .flag `show true

/-- Elaborates and highlights Lean code in the current module context. -/
@[code_block]
def lean : CodeBlockExpanderOf LeanArgs
  | { «show» }, str => elabAndHighlightLean «show» str

structure VersoSourceArgs where
  linkName? : Option Ident

section
variable [Monad m] [MonadError m]

instance : ArgParse.FromArgs VersoSourceArgs m where
  fromArgs := VersoSourceArgs.mk <$> .named `linkName .ident true  "the name to use for the source position of the code"
end

/-- A saved filename and line range used for links. -/
structure SourceLink where
  filename : String
  startLine : Nat
  endLine : Nat
deriving ToExpr, Repr

def SourceLink.permalink (rev : String) (link : SourceLink) : String :=
  s!"https://github.com/leanprover/verso-website/blob/{rev}/{link.filename}#L{link.startLine}-L{link.endLine}"

/--
The `versoSource` code block renders both the Verso code and its output.
-/
@[code_block]
def versoSource : CodeBlockExpanderOf VersoSourceArgs
  | { linkName? }, str => do
    if let some linkName := linkName? then
      let some range := (← getRef).getRange?
        | throwError "Can't save source line numbers because the code has no source position"
      let { start := { line := startLine, .. }, «end» := { line := endLine, .. } } := range.toLspRange (← getFileMap)
      let name := (← getCurrNamespace) ++ linkName.getId
      let fileName ← getFileName
      let cwd ← IO.Process.getCurrentDir
      let fileName := fileName.dropPrefix cwd.toString |>.dropPrefix "/" |>.copy
      let link := SourceLink.mk fileName (startLine + 1) (endLine + 1)
      addAndCompile <| .defnDecl {
        name,
        levelParams := [], type := .const ``SourceLink [],
        value := toExpr link,
        hints := .abbrev, safety := .safe
      }
      addConstInfo linkName name
      Hover.addCustomHover linkName s!"The source position {repr link}"
    highlightVersoSource str

structure VersoSourceLinkArgs where
  linkName : Ident

section
variable [Monad m] [MonadError m] [MonadLiftT CoreM m]

instance : ArgParse.FromArgs VersoSourceLinkArgs m where
  fromArgs := VersoSourceLinkArgs.mk <$> .positional `linkName .ident  "the source position of the code"
end

/--
Links to a saved source location.
-/
@[role]
def versoSourceLink : RoleExpanderOf VersoSourceLinkArgs
  | { linkName }, contents => do
    let linkN ← realizeGlobalConstNoOverloadWithInfo linkName

    -- Type checking here gives a better error message than just emitting code
    let ty ← Meta.inferType (← Meta.mkAppM linkN #[])
    unless (← Meta.isDefEq ty (.const ``SourceLink [])) do
      throwError m!"Expected `{.ofConstName linkN}` to be a `{.ofConstName ``SourceLink}`, but got a `{.ofExpr ty}`"

    -- Get the current Git rev
    let rev ← IO.Process.run { cmd := "git", args := #["rev-parse", "HEAD"] }
    let rev := rev.trimAscii.copy

    -- Use the already-resolved name rather than re-resolving
    let linkName := mkCIdentFrom linkName.raw linkN
    ``(Inline.link #[$(← contents.mapM elabInline),*] (SourceLink.permalink $(quote rev) $linkName))

/-- The contents are ignored. -/
@[code_block]
def comment : CodeBlockExpanderOf NoArgs
  | _, _ => ``(Block.empty)
