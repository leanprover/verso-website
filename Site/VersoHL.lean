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
open Lean.Doc.Syntax
open SubVerso.Highlighting

namespace Site

def codeSeq [Monad m] [MonadError m] (xs : TSyntaxArray `inline) : m (Array StrLit) := do
  xs.filterMapM fun
    | `(inline|code($s)) => pure (some s)
    | `(inline|$s:str) =>
      if s.getString.all (·.isWhitespace) then pure none
      else throwErrorAt s "Expected code"
    | i => throwErrorAt i "Expected code"

/-- CSS class and hover tooltip for a Verso syntax node kind. -/
def versoTokenInfo : SyntaxNodeKind → Option (String × String)
  | ``header => some ("verso-header", "A section header that creates document structure")
  | ``codeblock => some ("verso-codeblock", "A code block, interpreted according to the name")
  | ``Lean.Doc.Syntax.directive => some ("verso-directive", "A directive that invokes a registered block extension")
  | ``Lean.Doc.Syntax.role => some ("verso-role", "A role that invokes a registered inline extension")
  | ``code => some ("verso-code", "Inline code, rendered as monospace")
  | ``bold => some ("verso-bold", "Bold, rendered as strong text")
  | ``emph => some ("verso-emph", "Emphasis, rendered as italics")
  | ``link => some ("verso-link", "Hyperlink")
  | ``image => some ("verso-image", "Image")
  | ``blockquote => some ("verso-blockquote", "Block quote")
  | ``inline_math => some ("verso-math", "Inline math, rendered with KaTeX")
  | ``display_math => some ("verso-math", "Display math, rendered with KaTeX")
  | ``metadata_block => some ("verso-metadata", "Metadata block")
  | ``footnote => some ("verso-footnote", "Footnote definition")
  | ``link_ref => some ("verso-link-ref", "Link reference")
  | ``footnote_ref => some ("verso-footnote-ref", "Footnote reference")
  | ``arg_num => some ("verso-arg", "Numeric argument")
  | ``arg_ident => some ("verso-arg", "Named argument")
  | ``arg_str => some ("verso-arg", "String argument")
  | ``Lean.Doc.Syntax.flag_on => some ("verso-flag", "Boolean flag (on)")
  | ``Lean.Doc.Syntax.flag_off => some ("verso-flag", "Boolean flag (off)")
  | _ => none

/-- Render text as an optionally-styled span. -/
private def styledSpan (text : String) : Option (String × String) → Output.Html
  | some (cls, tip) => {{ <span class={{cls}} data-tooltip={{tip}}>{{text}}</span> }}
  | none => text

/-- Render a syntax tree as highlighted HTML, building nesting directly from the tree structure.
    Walks the syntax tree and source string together, emitting gap text between positioned nodes. -/
private partial def renderSource (src : String) (stx : Syntax)
    (hoverMap : Std.HashMap String.Pos.Raw String)
    (ancestorInfo : Option (String × String) := none) : Output.Html :=
  match stx with
  | .atom _ val =>
    match stx.getPos?, stx.getTailPos? with
    | some start, some stop =>
      let text : String := start.extract src stop
      -- Inside roles: braces get delim class
      if ancestorInfo.map (·.1) == some "verso-role" && (val == "{" || val == "}") then
        styledSpan text (some ("verso-role-delim", ancestorInfo.map (·.2) |>.getD ""))
      -- Inside links: brackets/parens get delim class
      else if ancestorInfo.map (·.1) == some "verso-link" &&
              (val == "[" || val == "]" || val == "(" || val == ")") then
        styledSpan text (some ("verso-link-delim", ancestorInfo.map (·.2) |>.getD ""))
      -- Inside directives: ::: get delim class
      else if ancestorInfo.map (·.1) == some "verso-directive" &&
              val.trimAsciiStart.startsWith ":::" then
        styledSpan text (some ("verso-directive-delim", ancestorInfo.map (·.2) |>.getD ""))
      -- Inside codeblocks: fences get fence class, names get name class
      else if ancestorInfo.map (·.1) == some "verso-codeblock" then
        let tip := ancestorInfo.map (·.2) |>.getD ""
        if val.trimAsciiStart.startsWith "```" then styledSpan text (some ("verso-codeblock-fence", tip))
        else if val.all Char.isWhitespace then text
        else styledSpan text (some ("verso-ext-name", hoverMap[start]?.getD tip))
      else
        -- Don't color plain text inside directives
        let info := if ancestorInfo.map (·.1) == some "verso-directive" then none else ancestorInfo
        if let some hoverText := hoverMap[start]? then
          styledSpan text (some (info.map (·.1) |>.getD "", hoverText))
        else styledSpan text info
    | _, _ => .empty
  | .ident .. =>
    match stx.getPos?, stx.getTailPos? with
    | some start, some stop =>
      let text : String := start.extract src stop
      if ancestorInfo.map (·.1) == some "verso-codeblock" ||
         ancestorInfo.map (·.1) == some "verso-role" ||
         ancestorInfo.map (·.1) == some "verso-directive" then
        let tip := hoverMap[start]?.getD (ancestorInfo.map (·.2) |>.getD "")
        styledSpan text (some ("verso-ext-name", tip))
      else
        let info := if ancestorInfo.map (·.1) == some "verso-directive" then none else ancestorInfo
        if let some hoverText := hoverMap[start]? then
          styledSpan text (some (info.map (·.1) |>.getD "", hoverText))
        else styledSpan text info
    | _, _ => .empty
  | .node _ kind args =>
    let info := versoTokenInfo kind |>.orElse fun () => ancestorInfo
    -- Inline markup: single span covering the whole node
    if kind == ``bold || kind == ``emph || kind == ``code || kind == ``inline_math then
      match stx.getPos?, stx.getTailPos? with
      | some start, some stop => styledSpan (start.extract src stop) info
      | _, _ => .empty
    -- Roles: wrapper span (hover background only) with recursive children
    else if kind == ``Lean.Doc.Syntax.role then
      {{ <span class="verso-role-wrap">{{renderChildren src args hoverMap info stx}}</span> }}
    -- Links: wrapper span (hover background only) with recursive children
    else if kind == ``link then
      {{ <span class="verso-link-wrap">{{renderChildren src args hoverMap info stx}}</span> }}
    -- Directives: wrapper span (hover background only), children rendered inside
    else if kind == ``Lean.Doc.Syntax.directive then
      {{ <span class="verso-directive-wrap">{{renderChildren src args hoverMap info stx}}</span> }}
    -- Codeblocks: wrapper span (hover background only), children rendered inside
    else if kind == ``codeblock then
      {{ <span class="verso-codeblock-wrap">{{renderChildren src args hoverMap info stx}}</span> }}
    -- Code block string content: tooltip but no special class
    else if kind == strLitKind && ancestorInfo.map (·.1) == some "verso-codeblock" then
      match stx.getPos?, stx.getTailPos? with
      | some start, some stop =>
        let text : String := start.extract src stop
        let tip := ancestorInfo.map (·.2) |>.getD ""
        styledSpan text (some ("verso-codeblock-content", tip))
      | _, _ => .empty
    -- Default: recurse into children
    else renderChildren src args hoverMap info stx
  | .missing => .empty
where
  renderChildren (src : String) (args : Array Syntax)
      (hoverMap : Std.HashMap String.Pos.Raw String)
      (ancestorInfo : Option (String × String))
      (parent : Syntax) : Output.Html := Id.run do
    let mut parts : Array Output.Html := #[]
    let mut pos : String.Pos.Raw := parent.getPos?.getD 0
    for arg in args do
      match arg.getPos? with
      | some argStart =>
        if argStart > pos then
          parts := parts.push (pos.extract src argStart)
        parts := parts.push (renderSource src arg hoverMap ancestorInfo)
        pos := arg.getTailPos?.getD argStart
      | none => pure ()
    let endPos := parent.getTailPos?.getD pos
    if pos < endPos then
      parts := parts.push (pos.extract src endPos)
    .seq parts

/-- Elaborate Lean source code as commands and return SubVerso-highlighted output. -/
private def elabAndHighlightLean («show» : Bool) (src : StrLit) : DocElabM (TSyntax `term) := withoutAsync do
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
  let mut pstate : Parser.ModuleParserState := { pos }
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
def highlightVersoSource (src : StrLit) : DocElabM (TSyntax `term) := do
  let srcStr := (← getFileMap).source
  let pos := src.raw.getPos!
  let pos' := src.raw.getTailPos? |>.getD srcStr.rawEndPos
  let pos' := if pos' > srcStr.rawEndPos then srcStr.rawEndPos else pos'
  have : pos' ≤ srcStr.rawEndPos := by grind
  let ictx := Parser.mkInputContext srcStr (← getFileName) (endPos := pos') (endPos_valid := by grind)
  let stx ← Doc.parseStrLit (Verso.Parser.document {}) src

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
  let highlighted := renderSource (← getFileMap).source stx hoverMap
  let sourceHtml := {{ <pre class="verso-source"><code>{{highlighted}}</code></pre> }}
  let blobId := mkIdent ``Verso.Genre.Blog.BlockExt.blob
  let sourceBlock ← ``(Block.other ($blobId $(quote sourceHtml)) #[])
  let sourcePanel ←
    ``(Block.other (Verso.Genre.Blog.BlockExt.htmlDiv "verso-source-panel") #[$sourceBlock])
  let outputPanel ←
    ``(Block.other (Verso.Genre.Blog.BlockExt.htmlDiv "verso-output-panel")
      #[$[$outputBlocks],*])
  ``(Block.other (Verso.Genre.Blog.BlockExt.htmlDiv "verso-demo") #[$sourcePanel, $outputPanel])

structure TheoremArgs where
  name : String

section
open ArgParse
variable {m} [Monad m] [MonadError m]

instance : FromArgs TheoremArgs m where
  fromArgs := TheoremArgs.mk <$> .positional `name .string "the theorem name"
end

block_component theoremC (name : String) where
  toHtml _ _ _ go contents := do
    return {{
      <div class="theorem"><div class="theorem-name">{{name}}</div>{{ ← contents.mapM go }}</div>
    }}

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

open Verso.Genre.Blog in
/-- Elaborates and highlights Lean code in the current module context. -/
@[code_block]
def lean : CodeBlockExpanderOf LeanArgs
  | { «show» }, str => elabAndHighlightLean «show» str
end Site

open Site in
open Verso.Genre.Blog in
/--
The `versoSource` code block renders both the Verso code and its output.
-/
@[code_block]
def versoSource : CodeBlockExpanderOf NoArgs
  | ⟨⟩, str => highlightVersoSource str

open Site in
open Verso.Genre.Blog in
/-- The contents are ignored. -/
@[code_block]
def comment : CodeBlockExpanderOf NoArgs
  | _, _ => `(Block.empty)
