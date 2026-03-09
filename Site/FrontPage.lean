import VersoBlog
import Site.Meta
import Site.VersoHL
import Site.Tactic

open Verso Genre
open Blog hiding lean
open Site

#doc (Page) "Verso" =>

::::htmlDiv (class := "hero")

:::htmlDiv (class := "hero-text")

Verso

Written in Lean. Checked by Lean.

Verso is a platform for writing documents, books, course materials, and websites with [Lean](https://lean-lang.org).
Every code example is type-checked. Every rendered page is interactive. And it's all
built on the tools you already use.

[Get Started with Templates »](https://github.com/leanprover/verso-templates)

:::

```comment
The Verso code and its rendering on the front page are produced automatically from this code block.
```

````versoSource
The type of all predicates over a type is that type's _powerset_. Elements of one of these subsets satisfy the predicate:
```lean
def Set (α : Type u) : Type u :=
  α → Prop

instance : Membership α (Set α) where
  mem xs x := xs x
```
A function $`f` is surjective if each element of the range is covered by an element of the domain:
```lean
def Surjective (f : α → β) :=
  ∀ y, ∃ x, f x = y
```
:::theorem "Cantor"
Given a function $`f ∈ S → \mathcal{P}(S)`, [Cantor's diagonal argument](https://en.wikipedia.org/wiki/Cantor%27s_diagonal_argument) involves the diagonal set $`\{x ∈ S \mid x \not\in f(x)\}`. The {tactic}`grind` tactic takes care of many reasoning steps:
```lean
theorem cantor (f : S → Set S) : ¬ Surjective f := by
  intro h
  have ⟨x, p⟩ := h (fun x : S => x ∉ f x)
  have : x ∈ f x ↔ x ∉ f x := by
    constructor <;>
    simp [Membership.mem] at * <;>
    grind
  grind
```
:::
````

::::

:::::html div (class := "pillars") (id := "why-verso")

::::htmlDiv (class := "pillar")

*Interactive*

Verso files are Lean files. While writing, you get the full IDE experience, including autocomplete, error checking, go-to-definition, and tactic states. Readers get the same richness: rendered pages include proof states, hover information, and clickable links to documentation.

{lightbox (alt:="A screenshot showing proof states and hover info") (full := "static/interactive.png") (thumb := "static/interactive-thumb.png")}[]

::::

::::htmlDiv (class := "pillar")

*Correct*

Verso helps you catch mistakes while writing, not after publishing. Every code example is checked by Lean as part of the build. If a described behavior doesn't match reality, you find out immediately. The Lean Reference Manual uses this to stay up to date with the latest developments.

{lightbox (alt := "A screenshot showing a #guard_msgs test that fails in text") (full := "static/correct.png") (thumb := "static/correct-thumb.png")}[]

::::

::::htmlDiv (class := "pillar")

*Integrated*

Built on Lean and Lake. Verso uses a lightweight Markdown-like markup language with a built-in extension mechanism. Extensions are ordinary Lean functions, not a separate plugin system or templating language. Syntax highlighting uses Lean's actual parser, so it's always accurate.

{lightbox (alt := "A screenshot showing a Verso extension") (full := "static/integration.png") (thumb := "static/integration-thumb.png")}[]


::::

:::::

::::::html div (class := "builds") (id := "what-to-build")

*What Can You Build?*

Verso's provides a shared foundation for rendering, cross-referencing, and code integration, without requiring a single core model that only really fits one kind of document.
Different kinds of documents are called _genres_.
Each genre builds on common infrastructure, so improvements to one benefit all, and anyone can implement a new genre.

:::::htmlDiv (class := "build-cards")

::::htmlDiv (class := "build-card")

*Reference Manuals*

Comprehensive API and language documentation

::::

::::htmlDiv (class := "build-card")

*Course Notes & Textbooks*

Structured educational material with worked examples

::::

::::htmlDiv (class := "build-card")

*Websites & Blogs*

A static site generator for project homepages, landing pages, and blog posts with integrated Lean code

::::

::::htmlDiv (class := "build-card")

*Mathematical Blueprints*

Plans for large-scale formalization projects

::::

::::htmlDiv (class := "build-card")

*Your Document Here*

Verso's genre system is extensible: you can define new document types with custom rendering and cross-referencing

::::

:::::

::::::

::::::html div (class := "showcase") (id := "showcase")

*Built with Verso*

:::::htmlDiv (class := "showcase-cards")

::::htmlDiv (class := "showcase-card reference")

[*Lean Reference Manual*](https://lean-lang.org/doc/reference/latest/)

The official Lean language reference

::::

::::htmlDiv (class := "showcase-card website")

[*lean-lang.org*](https://lean-lang.org/)

The Lean project website

::::

::::htmlDiv (class := "showcase-card textbook")

[*Theorem Proving in Lean 4*](https://lean-lang.org/theorem_proving_in_lean4/)

An introduction to using Lean as a proof assistant

::::

::::htmlDiv (class := "showcase-card textbook")

[*Functional Programming in Lean*](https://lean-lang.org/functional_programming_in_lean/)

A hands-on guide to programming in Lean

::::

::::htmlDiv (class := "showcase-card course")

[*Analysis I*](https://teorth.github.io/analysis/)

Terry Tao's _Analysis I: a Lean Companion_

::::

::::htmlDiv (class := "showcase-card website")

[*This Very Page*](https://github.com/TODO)

This page is built in Verso.

::::

:::::

::::::

::::::html div (id := "get-started") (class := "get-started")

*Ready to try Verso?*

:::::htmlDiv (class := "get-started-links")

::::htmlDiv (class := "get-started-item")

*Templates*

Start from a template for a textbook or blog.

[Get Started»](https://github.com/leanprover/verso-templates)

::::

::::htmlDiv (class := "get-started-item")

*User Manual*

Learn how Verso works.

[Read the manual»](https://verso-user-manual.netlify.app/)

::::

::::htmlDiv (class := "get-started-item")

*Community*

Ask questions and share what you're building in the Verso channel on the Lean community Zulip.

[Join Zulip»](https://leanprover.zulipchat.com/#narrow/channel/576452-verso)

::::

:::::

::::::
