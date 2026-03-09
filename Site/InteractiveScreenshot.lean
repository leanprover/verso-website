/-
Copyright (c) 2026 Lean FRO, LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: David Thrane Christiansen
-/
import VersoBlog
import Site.Meta
import Site.VersoHL
import Site.Tactic

open Verso Genre
open Blog hiding lean
open Site

#doc (Page) "Verso" =>

The type of all predicates over a type is that type's _powerset_.
Elements of one of these subsets satisfy the predicate:
```lean
def Set (α : Type u) : Type u := α → Prop

instance : Membership α (Set α) where
  mem xs x := xs x
```
A function $`f` is surjective if each element of the range is covered
by an element of the domain:
```lean
def Surjective (f : α → β) := ∀ y, ∃ x, f x = y
```
:::theorem "Cantor"
Given a function $`f ∈ S → \mathcal{P}(S)`, [Cantor's diagonal
argument](https://en.wikipedia.org/wiki/Cantor%27s_diagonal_argument)
involves the diagonal set $`\{x ∈ S \mid x \not\in f(x)\}`.
The {tactic}`grind` tactic takes care of many reasoning steps:
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
