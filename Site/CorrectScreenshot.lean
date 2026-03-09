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

#doc (Page) "Sort Stability" =>

This is an incorrect statement: QuickSort is stable.

```lean -show
/-- info: #[(1, "a"), (1, "b"), (2, "c")] -/
#guard_msgs in
#eval #[(1, "a"), (2, "c"), (1, "b")].qsort (·.1 < ·.1)
```
