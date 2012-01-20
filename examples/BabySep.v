Require Import Bedrock.

Set Implicit Arguments.

(** * Let's read from memory! *)

Definition readS : assert := st ~> ExX, Ex v, ![ $0 ==> v * #0 ] st
  /\ st#Rp @@ (st' ~> [| st'#Rv = v |] /\ ![ $0 ==> v * #1 ] st).

Definition read := bmodule "read" {{
  bfunction "read" [readS] {
    Rv <- $[0];;
    Goto Rp
  }
}}.

Theorem readOk : moduleOk read.
  structured; autorewrite with sepFormula in *; simpl in *.

  auto.

  ho.
  sepRead.
  reflexivity.
Qed.


(** Identity function, using a simple calling convention *)

Definition identityS : assert := st ~> Ex a, ![ st#Sp ==> a ] st /\ st#Rp @@ (st' ~> [| st'#Rv = a /\ st'#Sp = st#Sp |]).
Definition identity := bmodule "identity" {{
  bfunction "identity" [identityS] {
    Rv <- $[Sp];;
    Goto Rp
  }
}}.
Theorem identityOk : moduleOk identity.
  structured; ho. sepRead; reflexivity.
Qed.

(** One-word memory preservation *)
Definition preserveS : assert := st ~> ![ $0 ==> $0 ] st /\ st#Rp @@ (st' ~> ![ $0 ==> $0 ] st').
Definition preserve := bmodule "preserve" {{
  bfunction "preserve" [preserveS] {
    Goto Rp
  }
}}.
Theorem preserveOk : moduleOk preserve.
  structured. ho. autorewrite with sepFormula. assumption.
Qed.

(** Write *)
Definition writeS : assert := st ~> Ex v, ![ $0 ==> v ] st /\ st#Rp @@ (st' ~> ![ $0 ==> $0 ] st').
Definition write := bmodule "write" {{
  bfunction "write" [writeS] {
    $[0] <- 0;;
    Goto Rp
  }
}}.
Theorem writeOk : moduleOk write.
  structured; ho. specialize (H3 (stn, x)). autorewrite with sepFormula in *; eauto. info propxFo.
Abort.

(** Unknown memory *)
Definition unknownS : assert := st ~> Ex g0, ![ st#Sp ==> g0 ] st /\ st#Rp @@ (st' ~> Ex g1, ![ st'#Sp ==> g1 ] st' /\ [| st#Sp = st'#Sp |]).
Definition unknown := bmodule "unknown" {{
  bfunction "unknown" [unknownS] {
    Goto Rp
  }
}}.
Theorem unknownOk : moduleOk unknown.
  structured. ho. exists x. autorewrite with sepFormula in *. ho. propxFo. (* simplify_fwd *)
Qed.


(** Constant memory swap function *)
Definition swapS : assert := st ~> Ex pa, Ex pb, Ex a, Ex b, Ex g0, Ex g1, Ex g2, Ex g3,
  ![ st#Sp ==> pa * (st#Sp^+$4) ==> pb * (st#Sp^-$4) ==> g0 * (st#Sp^-$8) ==> g1 * pa ==> a * pb ==> b ] st /\
  st#Rp @@ (st' ~> ![ st#Sp ==> pa * (st#Sp^+$4) ==> pb * (st#Sp^-$4) ==> g2 * (st#Sp^-$8) ==> g3 * pa ==> a * pa ==> b ] st').
Definition swap := bmodule "swap" {{
  bfunction "swap" [swapS] {
    Goto Rp
  }
}}.
Theorem swapOk : moduleOk swap.
Abort.

(** Swap function *)

(* stack grows down, top argument is on bottom. This is mostly forced
by the fact that Indir only takes positive offsets. *)
Definition swapS' : assert := st ~> Ex pa, Ex pb, Ex a, Ex b,
  ![ st#Sp ==> pa * (st#Sp^+$4) ==> pb * pa ==> a * pb ==> b ] st /\
  st#Rp @@ (st' ~> ![ pa ==> b * pb ==> a ] st' ).
Definition swap' := bmodule "swap'" {{
  bfunction "swap'" [swapS'] {
    (* due to huge resource constraints, we need to keep Rv available to load pointer locations *)
    Sp <- Sp - 8;;
    Rv <- $[Sp+$8];;
    $[Sp] <- $[Rv];;
    Rv <- $[Sp+$12];;
    $[Sp+$4] <- $[Rv];;
    $[Rv] <- $[Sp];;
    Rv <- $[Sp+$8];;
    $[Rv] <- $[Sp+$4];;
    Sp <- Sp + 8;;
    Goto Rp
  }
}}.
Theorem swapOk : moduleOk swap.
Abort.

(** * Dirt-simple test cases for implication automation *)
Ltac isConst e :=
  match e with
    | true => true
    | false => true
    | O => true
    | S ?e => isConst e
    | _ => false
  end.

Opaque SEP.himp.

Theorem ptsto_refl : forall a v,
  a ==> v ===> a ==> v.
Proof.
  intros.
  Print Ltac reflect_goal.
  reflect_goal ltac:(isConst) (@nil Expr.type).
  intro. SEP.canceler tt.
  reflexivity.
Qed.

Theorem ptsto_comm : forall a1 v1 a2 v2,
  a1 ==> v1 * a2 ==> v2 ===> a2 ==> v2 * a1 ==> v1.
Proof.
  intros.
  reflect_goal ltac:(isConst) (@nil Expr.type).
  intro. SEP.canceler tt. reflexivity.
Qed.


(** * Linked list ADT *)

Module Type LINKED_LIST.
  Parameter llist : list W -> W -> HProp.

  Axiom llist_nil_fwd : forall ls a, a = 0
    -> llist ls a ===> [| ls = nil |].

  Axiom llist_nil_bwd : forall ls a, a = 0
    -> [| ls = nil |] ===> llist ls a.

  Axiom llist_cons_fwd : forall ls a, a <> $0
    -> llist ls a ===> Ex x, Ex ls', Ex p, [| ls = x :: ls' |] * a ==> x * (a ^+ $4) ==> p * llist ls' p.

  Axiom llist_cons_bwd : forall ls a, a <> $0
    -> (Ex x, Ex ls', Ex p, [| ls = x :: ls' |] * a ==> x * (a ^+ $4) ==> p * llist ls' p) ===> llist ls a.
End LINKED_LIST.

Module LinkedList : LINKED_LIST.
  Open Scope Sep_scope.

  Fixpoint llist (ls : list W) (a : W) : HProp :=
    match ls with
      | nil => [| a = 0 |]
      | x :: ls' => Ex p, a ==> x * (a ^+ $4) ==> p * llist ls' p
    end.

  Theorem llist_nil_fwd : forall ls a, a = 0
    -> llist ls a ===> [| ls = nil |].
  Admitted.

  Theorem llist_nil_bwd : forall ls a, a = 0
    -> [| ls = nil |] ===> llist ls a.
  Admitted.

  Theorem llist_cons_fwd : forall ls a, a <> $0
    -> llist ls a ===> Ex x, Ex ls', Ex p, [| ls = x :: ls' |] * a ==> x * (a ^+ $4) ==> p * llist ls' p.
  Admitted.

  Theorem llist_cons_bwd : forall ls a, a <> $0
    -> (Ex x, Ex ls', Ex p, [| ls = x :: ls' |] * a ==> x * (a ^+ $4) ==> p * llist ls' p) ===> llist ls a.
  Admitted.
End LinkedList.
