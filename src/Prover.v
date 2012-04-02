Require Import List Arith Bool.
Require Import Expr Env.

Set Implicit Arguments.
Set Strict Implicit.

(** Provers that establish [expr]-encoded facts *)

Definition ProverCorrect types (fs : functions types) (summary : Type)
    (** Some prover work only needs to be done once per set of hypotheses,
       so we do it once and save the outcome in a summary of this type. *)
  (valid : env types -> env types -> summary -> Prop)
  (prover : summary -> expr types -> bool) : Prop :=
  forall vars uvars sum,
    valid uvars vars sum ->
    forall goal, 
      prover sum goal = true ->
      ValidProp fs uvars vars goal ->
      Provable fs uvars vars goal.

Record ProverT (types : list type) : Type :=
{ Facts : Type
; Summarize : exprs types -> Facts
; Learn : Facts -> exprs types -> Facts
; Prove : Facts -> expr types -> bool
}.

Record ProverT_correct (types : list type) (P : ProverT types) (funcs : functions types) : Type :=
{ Valid : env types -> env types -> Facts P -> Prop
; Summarize_correct : forall uvars vars hyps, 
  AllProvable funcs uvars vars hyps ->
  Valid uvars vars (Summarize P hyps)
; Learn_correct : forall uvars vars facts,
  Valid uvars vars facts -> forall hyps,
  AllProvable funcs uvars vars hyps ->
  Valid uvars vars (Learn P facts hyps)
; Prove_correct : ProverCorrect funcs Valid (Prove P)
}.

(** Generic lemmas/tactis to prove things about provers **)

Lemma eq_nat_dec_correct : forall (n : nat), eq_nat_dec n n = left eq_refl.
  induction n; provers.
Qed.
Hint Rewrite eq_nat_dec_correct : provers.

Lemma nat_seq_dec_correct : forall (n : nat), seq_dec n n = Some eq_refl.
  unfold seq_dec. provers.
Qed.
Hint Rewrite nat_seq_dec_correct : provers.


(* Everything looks like a nail?  Try this hammer. *)
Ltac t1 := match goal with
             | _ => discriminate
             | _ => progress (hnf in *; simpl in *; intuition; subst)
             | [ x := _ : _ |- _ ] => subst x || (progress (unfold x in * ))
             | [ H : ex _ |- _ ] => destruct H
             | [ H : context[nth_error (updateAt ?new ?ls ?n) ?n] |- _ ] =>
               rewrite (nth_error_updateAt new ls n) in H
                 || rewrite nth_error_updateAt in H
             | [ s : signature _ |- _ ] => destruct s
             | [ H : Some _ = Some _ |- _ ] => injection H; clear H
             | [ H : _ = Some _ |- _ ] => rewrite H in *
             | [ H : _ === _ |- _ ] => rewrite H in *

             | [ |- context[match ?E with
                              | Const _ _ => _
                              | Var _ => _
                              | UVar _ => _
                              | Func _ _ => _
                              | Equal _ _ _ => _
                            end] ] => destruct E
             | [ |- context[match ?E with
                              | None => _
                              | Some _ => _
                            end] ] => destruct E
             | [ |- context[if ?E then _ else _] ] => 
               case_eq E; intro
             | [ |- context[match ?E with
                              | nil => _
                              | _ :: _ => _
                            end] ] => destruct E
             | [ H : _ || _ = true |- _ ] => apply orb_true_iff in H; destruct H
             | [ _ : context[match ?E with
                               | Const _ _ => _
                               | Var _ => _
                               | UVar _ => _
                               | Func _ _ => _
                               | Equal _ _ _ => _
                             end] |- _ ] => destruct E
             | [ _ : context[match ?E with
                               | nil => _
                               | _ :: _ => _
                             end] |- _ ] => destruct E
             | [ H : context[if ?E then _ else _] |- _ ] => 
               revert H; case_eq E; do 2 intro
             | [ _ : context[match ?E with
                               | left _ => _
                               | right _ => _
                             end] |- _ ] => destruct E
             | [ _ : context[match ?E with
                               | tvProp => _
                               | tvType _ => _
                             end] |- _ ] => destruct E
             | [ _ : context[match ?E with
                               | None => _
                               | Some _ => _
                             end] |- _ ] => match E with
                                              | context[match ?E with
                                                          | None => _
                                                          | Some _ => _
                                                  end] => fail 1
                                              | _ => destruct E
                                            end

             | [ _ : context[match ?E with (_, _) => _ end] |- _ ] => destruct E
           end.

Ltac t := repeat t1; eauto.
