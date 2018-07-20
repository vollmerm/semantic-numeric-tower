Require Import Coq.ZArith.BinInt.
Require Import List.
Require Import Omega.
Require Import Ensembles.
Require Import Classical_sets.
Require Import Coq.Logic.Classical_Prop.
Require Import Powerset.
Require Import Image.
Require Import Relations.
Require Import CpdtTactics.
Require Import LibTactics.
Require Import Misc.

Set Implicit Arguments.

Open Scope list_scope.

(* * * * * * * * * * * * * * * * * * * * * * * * *)
(*                 Definitions                   *)
(* * * * * * * * * * * * * * * * * * * * * * * * *)

Axiom V : Type.
Axiom V_eq_dec : forall (v1 v2: V), {v1 = v2} + {v1 <> v2}.
Notation Ty := (Ensemble V).

Notation emptyTy := (Empty_set V).
Notation anyTy := (Full_set V).
Notation tyOr := (Union V).
Notation tyAnd := (Intersection V).
Notation tyDiff := (Setminus V).
Notation tyNot := (tyDiff anyTy).

Notation IsEmpty t := (~ Inhabited V t).
Notation IsInhabited t := (Inhabited V t).
Axiom IsEmpty_dec : forall (t: Ty), {IsEmpty t} + {IsInhabited t}.
Notation IsA v T := (In V T v).
Axiom IsA_dec : forall (v:V) (t: Ty), {IsA v t} + {~ IsA v t}.
Notation "T1 <: T2" := (Included V T1 T2) (at level 70).

Hint Unfold Included Setminus.
Hint Constructors Union Intersection Inhabited.


Lemma no_empty_val : forall v,
    ~ IsA v emptyTy.
Proof.
  intros v Hmt. inversion Hmt.
Qed.



(* A single function arrow *)
Inductive arrow : Type :=
| Arrow : Ty -> Ty -> arrow.
Hint Constructors arrow.

Inductive res : Type :=
| Err : res (* invalid argument/type error *)
| Bot : res (* non-termination *)
| Res : V -> res. (* a value result *)
Hint Constructors res.

Definition fn := (V -> res).


Ltac destruct_IsA :=
  match goal with
  | [H : IsA _ _ |- _] => destruct H
  end.


Ltac same_Res :=
  match goal with
  | [H1 : ?f ?v = Res ?x , H2 : ?f ?v = Res ?y |- _] =>
    rewrite H1 in H2; inversion H2; subst; clear H2
  end.


Inductive interface : Type :=
| IBase: arrow -> interface
| ICons : arrow -> interface -> interface.
Hint Constructors interface.

Fixpoint i_dom (i : interface) : Ty :=
  match i with
  | IBase (Arrow T1 _) => T1
  | ICons (Arrow T1 _) i' => tyOr T1 (i_dom i')
  end.
Hint Unfold i_dom.


Fixpoint a_result (a : arrow) (v : V) : option Ty :=
  match a with
  | Arrow T1 T2 => if IsA_dec v T1
                   then Some T2
                   else None
  end.
Hint Unfold a_result.

Definition FnA (f : fn) (a : arrow) : Prop :=
forall v T,
  a_result a v = Some T ->
  (f v = Bot \/ exists v', f v = Res v' /\ IsA v' T).
Hint Unfold FnA.

Fixpoint i_result (i : interface) (v : V) : option Ty :=
  match i with
  | IBase a => a_result a v
  | ICons a i' => match a_result a v, i_result i' v with
                  | None, None => None
                  | Some T, None => Some T
                  | None, Some T => Some T
                  | Some T, Some T' => Some (tyAnd T T')
                  end
  end.
Hint Unfold i_result.

(* Function Interface *)
Definition FnI (f : fn) (i : interface) : Prop :=
forall v T,
  i_result i v = Some T ->
  (f v = Bot \/ exists v', f v = Res v' /\ IsA v' T).
Hint Unfold FnI.

Lemma FnI_base : forall f a,
    FnI f (IBase a) ->
    FnA f a.
Proof.
  unfold FnI. unfold FnA.
  intros f [T1 T2] H v T Har.
  assert (forall T,
             i_result (IBase (Arrow T1 T2)) v = Some T ->
             f v = Bot \/ (exists v' : V, f v = Res v' /\ IsA v' T))
    as H'. eauto. clear H.
  unfold a_result in *. simpl in *.
  ifcaseH; crush.
Qed.

Lemma FnI_first : forall f a i,
    FnI f (ICons a i) ->
    FnA f a.
Proof.
  unfold FnI. unfold FnA.
  intros f [T1 T2] i H v T Har.
  assert (forall T,
             i_result (ICons (Arrow T1 T2) i) v = Some T ->
             f v = Bot \/ (exists v' : V, f v = Res v' /\ IsA v' T))
    as H'. eauto. clear H.
  unfold a_result in *. simpl in *.
  ifcaseH; crush.
  destruct (i_result i v).
  assert (f v = Bot \/ (exists v' : V, f v = Res v'
                                       /\ IsA v' (tyAnd T e)))
    as Hdisj. eauto.
  crush.
  right. exists x.
  match goal with
    [H : IsA _ (tyAnd _ _) |- _] => inversion H; crush
  end.
  crush.
Qed.
  
Lemma FnI_rest : forall f a i,
    FnI f (ICons a i) ->
    FnI f i.
Proof.
  intros f [T1 T2] i Hfi.
  unfold FnI in Hfi.
  unfold FnI.
  intros v T Hir.
  remember (Hfi v) as H'.
  simpl in *. clear HeqH'.
  destruct (IsA_dec v T1).
  destruct (i_result i v).
  assert (f v = Bot \/ (exists v' : V, f v = Res v'
                                       /\ IsA v' (tyAnd T2 e)))
    as Hopt.
  apply H'. crush.
  destruct Hopt as [Hbot | [v' [Hres Hv']]]; auto.
  right. exists v'; crush. inversion Hv'; crush.
  inversion Hir.
  remember (H' T) as H''.
  clear HeqH''.
  rewrite Hir in H''.
  crush.
Qed.

Ltac inv_FnI :=
  match goal with
  | [H : FnI _ _ |- _] => inversion H; subst
  end.


Fixpoint i_neg (i : interface) (outT : Ty) : Ty :=
  match i with
  | IBase (Arrow T1 T2) =>
    if IsEmpty_dec (tyAnd T2 outT)
    then T1
    else emptyTy
  | ICons (Arrow T1 T2) i' =>
    let T := i_neg i' outT in
    let T' := tyAnd T1 (i_neg i' (tyAnd T2 outT)) in
    tyOr T T'
  end.

Definition i_inv (i : interface) (outT : Ty) : Ty :=
  tyDiff (i_dom i) (i_neg i outT).

Definition Inv
           (i:interface)
           (outT inT : Ty) : Prop :=
forall (f:fn),
  FnI f i ->
  forall (v v':V),
    IsA v (i_dom i) ->
    f v = Res v' ->
    IsA v' outT ->
    IsA v inT.

Definition InvNot
           (i:interface)
           (outT notInT : Ty) : Prop :=
forall (f:fn),
  FnI f i ->
  forall (v v':V),
    f v = Res v' ->
    IsA v' outT ->
    ~ IsA v notInT.


Lemma FnA_res_ty : forall T1 T2 f x y,
    IsA x T1 ->
    f x = Res y ->
    FnA f (Arrow T1 T2) ->
    IsA y T2.
Proof.
  intros T1 T2 f x y Hx Hfx Hfa.
  assert (f x = Bot \/ exists y : V, f x = Res y /\ IsA y T2)
    as Hex.
  eapply Hfa; crush.
  ifcase; crush.
  crush.
Qed.


Ltac solve_IsA :=
  match goal with
  | [Hx : IsA ?x ?T1,
     Hfy : ?f ?x = Res ?y,
     HFnA : FnA ?f (Arrow ?T1 ?T2)
     |- IsA ?y ?T2]
    => apply (FnA_res_ty x Hx Hfy HFnA)
  | [Hx : IsA ?x ?T1,
     Hfy : ?f ?x = Res ?y,
     HFnA : FnI ?f (IBase (Arrow ?T1 ?T2))
     |- IsA ?y ?T2]
     => apply (FnA_res_ty x Hx Hfy (FnI_first HFnA))
  | [Hx : IsA ?x ?T1,
     Hfy : ?f ?x = Res ?y,
     HFnA : FnI ?f (ICons (Arrow ?T1 ?T2) _)
     |- IsA ?y ?T2]
    => apply (FnA_res_ty x Hx Hfy (FnI_first HFnA))
  | [H1 : IsA ?x ?T1, H2 : IsA ?x ?T2 |- IsA ?x (tyAnd ?T1 ?T2)]
    => constructor; assumption
  | [H1 : IsA ?x ?T1 |- IsA ?x (tyOr ?T1 _)]
    => left; exact H1
  | [H2 : IsA ?x ?T2 |- IsA ?x (tyOr _ ?T2)]
    => left; exact H2
  end.

Hint Extern 1 (IsA _ _) => solve[solve_IsA].

Ltac apply_fun :=
  match goal with
  | [H1 : IsA ?x ?T1,
          Hf : FnI ?f (IBase (Arrow ?T1 ?T2)),
               Hres : ?f ?x = Res ?y
     |- _] =>
    assert (IsA y T2)
      by (exact (FnA_res_ty x H1 Hres (FnI_base Hf)))
  end.

Lemma in_i_neg : forall i v v' f T,
    FnI f i ->
    IsA v (i_neg i T) ->
    f v = Res v' ->
    ~ IsA v' T.
Proof with crush.
  intros i. induction i as [[T1 T2] | [T1 T2] i' IH]; crush.
  (* IBase (Arrow T1 T2) *)
  {
    destruct (IsEmpty_dec (tyAnd T2 T))
      as [Hmt | Hnmt].
    (* IsEmpty (tyAnd T2 T) *)
    {
      apply Hmt. exists v'.
      apply_fun...
    }
    (* IsInhabited (tyAnd T2 T) *)
    {
      eapply no_empty_val; eauto.
    }
  }
  (* ICons (Arrow T1 T2) i' *)
  {
    assert (FnI f i') by (eapply FnI_rest; eauto).
    match goal with
    | [H : IsA _ (tyOr _ _) |- _] => destruct H
    end.
    eapply IH; eauto. 
    match goal with
    | [H : IsA _ (tyAnd _ _) |- _] => destruct H
    end.
    eapply IH; eauto. 
  }
Qed.


Lemma i_neg_sound : forall i outT,
    InvNot i outT (i_neg i outT).
Proof with crush.
  unfold InvNot.
  intros i outT f Hfi v v' Hfv Hv' Hcontra.
  eapply in_i_neg; eauto.
Qed.

(* Interface Inversion Soundness *)
Lemma i_inv_sound : forall i outT,
    Inv i outT (i_inv i outT).
Proof with crush.
  unfold Inv.
  intros i outT f Hint v v' Hv Hf Hv'.
  unfold i_inv in *.
 constructor; auto.
 (* Show: ~ IsA v (i_neg i outT) *)
 intros Hcontra.
 eapply i_neg_sound; eauto.
Qed.

(* BOOKMARK *)

(*****************************************************************)
(*****************************************************************)
(*****************************************************************)
(**** Previous Approach Below ************************************)
(*****************************************************************)
(*****************************************************************)
(*****************************************************************)

(*
Inductive FnArrow : fn -> arrow -> Prop :=
| FnA : forall T1 T2 f,
    (forall v,
        IsA v T1 ->
        (f v = Bot
         \/ (exists v', IsA v' T2 /\ f v = Res v'))) ->
    FnArrow f (Arrow T1 T2).
Hint Constructors FnArrow.
*)
    
Inductive FnInterface : fn -> interface -> Prop :=
| FnIBase : forall f a,
    FnArrow f a ->
    FnInterface f (IBase a)
| FnICons : forall f a i',
    FnArrow f a ->
    FnInterface f i' ->
    FnInterface f (ICons a i').

Hint Constructors FnInterface.

Inductive InInterface : arrow -> interface -> Prop :=
| InBase : forall a, InInterface a (IBase a)
| InConsFirst : forall a i, InInterface a (ICons a i)
| InConsRest : forall a i, InInterface a i ->
                           InInterface a (ICons a i).
Hint Constructors InInterface.

Definition MapsTo (f : fn) (outT : Ty) : Prop :=
  forall T1 T2,
    FnArrow f (Arrow T1 T2) ->
    (IsInhabited (tyAnd T2 outT) ->
     forall v, IsA v T1 ->
               exists v', IsA v' (tyAnd T2 outT) /\
                          f v = Res v').

(* Similar to `exists_FnArrow`, we cannot prove
   `exists_FnInterface` but it is safe to assume. *)
Axiom exists_FnInterface : forall i outT,
    exists f, FnInterface f i /\ MapsTo f outT.
        

(* Append for interfaces *)
Fixpoint i_app (i1 i2 : interface) : interface :=
  match i1 with
  | IBase a => ICons a i2
  | ICons a i1' => ICons a (i_app i1' i2)
  end.
Hint Unfold i_app.

(* Map for interfaces *)
Fixpoint i_map (f : arrow -> arrow) (i : interface) : interface :=
  match i with
  | IBase a => IBase (f a)
  | ICons a i' => ICons (f a) (i_map f i')
  end.
Hint Unfold i_map.

(* non-empty subsets of an interface, as arrows with
   pointwise intersected domain and codomains *)
Fixpoint i_powerset (i : interface) : interface :=
  match i with
  | IBase a => IBase a
  | ICons a i' => let p := i_powerset i' in
                  (ICons a (i_app (i_map (a_meet a) p) p))
  end.
Hint Unfold i_powerset.

Lemma i_app_valid_i : forall i i' f,
    FnInterface f i ->
    FnInterface f i' ->
    FnInterface f (i_app i i').
Proof.
  intros i i' f Hi Hi'.
  induction Hi; crush.
Qed.

Lemma a_meet_arrow_fn : forall a a' f,
    FnArrow f a  ->
    FnArrow f a' ->
    FnArrow f (a_meet a a').
Proof with crush.
  intros a a' f Ha Ha'.
  repeat (match goal with
          | [H : FnArrow _ _ |- _] => destruct H
          end).
  constructor. intros.
  destruct_IsA.
  repeat applyHinH...
  right.
  match goal with
  | [H : _ _ = Res ?v |- _] => exists v; rewrite H in *
  end...
Qed.
Hint Resolve a_meet_arrow_fn.

  
Lemma a_meet_i : forall i f a,
    FnInterface f i ->
    FnArrow f a ->
    FnInterface f (i_map (a_meet a) i).
Proof with crush.
  intros i f a Hfi Hfa.
  induction Hfi...
Qed.

Lemma tyOr_assoc : forall T1 T2 T3,
    tyOr T1 (tyOr T2 T3) = tyOr (tyOr T1 T2) T3.
Proof.
  intros T1 T2 T3.
  apply Extensionality_Ensembles.
  constructor.
  {
    intros x Hx.
    destruct Hx as [x Hx | x Hx]; crush.
    destruct Hx as [x Hx | x Hx]; crush.
  }
  {
    intros x Hx.
    destruct Hx as [x Hx | x Hx]; crush.
    destruct Hx as [x Hx | x Hx]; crush.
  }
Qed.        


Lemma i_app_dom : forall i i',
    i_dom (i_app i i') = tyOr (i_dom i) (i_dom i').
Proof.
  intros i i'. induction i; crush.
Qed.

Lemma i_meet_dom : forall a i,
    i_dom (i_map (a_meet a) i)
    = tyAnd (a_dom a) (i_dom i).
Proof.
  intros [T1 T2] i.
  induction i as [[T3 T4] | [T3 T4] i' IH]; crush.
  apply Extensionality_Ensembles.
  constructor.
  {
    intros x Hx.
    destruct Hx as [x Hx | x Hx]; destruct Hx; crush.
  }
  {
    intros x Hx.
    destruct Hx as [x Hx1 Hx2].
    destruct Hx2 as [x Hx2 | x Hx2]; crush.
  }
Qed.  
  
  
Lemma i_powerset_dom : forall i,
    i_dom i = i_dom (i_powerset i).
Proof with crush.
  intros i.
  induction i...
  rewrite <- IHi.
  rewrite i_app_dom.
  rewrite <- IHi.
  apply Extensionality_Ensembles.
  constructor.
  (* _ <: _ direction *)
  {
    unfold Included.
    intros x Hx.
    inversion Hx; eauto.
  }
  (* _ :> _ direction *)
  {
    unfold Included.
    intros x Hx.
    destruct Hx as [x Hx | x Hx].
    left; auto.
    right.
    destruct Hx as [x Hx | x Hx]; auto.
    {
      rewrite i_meet_dom in Hx.
      inversion Hx; crush.
    }
  }
Qed.

Lemma i_powerset_interface : forall i i' f,
    FnInterface f i ->
    (i_powerset i) = i' -> 
    FnInterface f i'.
Proof with crush.
  intros i i' f Hfi Heq. subst.
  induction i... 
  assert (FnInterface f (i_powerset i)) as Hp...
  inversion Hfi; crush.
  constructor.
  inversion Hfi; auto.
  apply i_app_valid_i...
  apply a_meet_i...
  inversion Hfi...
Qed.

Fixpoint i_neg_aux (p: interface) (outT : Ty) : Ty :=
  match p with
  | IBase a => (a_neg a outT)
  | ICons a p' => tyOr (a_neg a outT) (i_neg_aux p' outT)
  end.

Definition i_neg (i : interface) (outT : Ty) : Ty :=
  i_neg_aux (i_powerset i) outT.

Hint Unfold i_neg i_neg_aux.


Definition i_inv (i:interface) (out:Ty) : Ty :=
  tyDiff (i_dom i) (i_neg i out).
Hint Unfold i_inv.


Definition InterfaceInv
           (i:interface)
           (outT inT : Ty) : Prop :=
forall (f:fn),
  FnInterface f i ->
  forall (v v':V),
    IsA v (i_dom i) ->
    f v = Res v' ->
    IsA v' outT ->
    IsA v inT.

Definition InterfaceInvNeg
           (i:interface)
           (outT notInT : Ty) : Prop :=
forall (f:fn),
  FnInterface f i ->
  forall (v v':V),
    IsA v (i_dom i) ->
    f v = Res v' ->
    IsA v' outT ->
    ~ IsA v notInT.


Ltac inv_FnInterface :=
  match goal with
  | [H : FnInterface _ _ |- _] => inversion H; subst
  end.

Lemma in_tyDiff : forall v T1 T2,
    IsA v T1 ->
    ~ IsA v T2 ->
    IsA v (tyDiff T1 T2).
Proof.
  crush.
Qed.

Lemma empty_counterexample : forall v T,
    IsA v T ->
    ~ IsEmpty T.
Proof.
  eauto.
Qed.


Lemma i_neg_sound : forall i outT notInT,
    i_neg i outT = notInT ->
    InterfaceInvNeg i outT notInT.
Proof with crush.
  intros i; induction i as [[T1 T2] | [T1 T2] i IHi].
  (* Case (IBase a) *)
  {
    unfold InterfaceInvNeg.
    intros outT notInT Hinv f Hint v v' hf Hv' Hcontra.
    subst. simpl in *.
    inv_FnInterface.
    eapply (a_neg_sound outT); eauto; crush.
  }
  (* Case (ICons a i) *)
  {
    unfold InterfaceInvNeg.
    intros outT notInT Hinv f Hint v v' Hdom Hf Hv' Hcontra.
    simpl in *. subst.
    inv_FnInterface.
    destruct Hcontra.
    (* IsA v (a_neg (Arrow T1 T2) outT) *)
    {
      unfold a_neg in *. simpl in *.
      destruct (IsEmpty_dec (tyAnd T2 outT))
        as [Hmt | Hnmt].
      (* IsEmpty (tyAnd (a_rng (Arrow T1 T2)) outT) *)
      {
        inv_FnArrow.
        assert (IsA x T1) as HT1 by assumption.
        applyHinH...
        same_Res.
        eauto.
      }
      (* IsInhabited (tyAnd (a_rng (Arrow T1 T2)) outT) *)
      {
        eapply no_empty_val; eassumption.
      }
    }
    (* IsA v (i_inv_neg i outT)  *)
    {
      assert (InterfaceInvNeg i outT (i_neg i outT)) as Hi; auto.
      destruct Hi with f x v'; crush.
      shelve.
      unfold i_neg.
    }
  }
Qed.

(* Interface Inversion Soundness *)
Lemma i_inv_sound : forall i outT inT,
    i_inv i outT = inT ->
    InterfaceInv i outT inT.
Proof with crush.
  unfold InterfaceInv.
  intros i outT inT Hinv f Hint v v' Hv Hf Hv'.
  unfold i_inv in *.
  remember (i_powerset i) as i'.
  assert (FnInterface f i') as Hi' by (eapply i_powerset_interface; eauto).
  clear Hint.
  rewrite <- Hinv. constructor; auto.
  (* Show: ~ IsA v (i_inv_neg i' outT) *)
  intros Hcontra.
  assert (InterfaceInvNeg i' outT (i_inv_neg i' outT)) as Hneg.
  {
    specialize i_inv_neg_sound with i' outT (i_inv_neg i' outT); eauto.
  }
  eapply Hneg; eauto.
Qed.

Lemma tyOr_empty_l : forall t,
    tyOr emptyTy t = t.
Proof.
  Admitted.

Lemma tyOr_empty_r : forall t,
    tyOr t emptyTy = t.
Proof.
  Admitted.


(*
Definition ArrowInvNeg 
           (a:arrow)
           (outT notInT : Ty) : Prop :=
forall (f:fn),
  FnArrow f a ->
  forall (v v':V),
    f v = Res v' ->
    IsA v' outT ->
    ~ IsA v notInT.
*)



(*
Definition InterfaceInvNeg
           (i:interface)
           (outT notInT : Ty) : Prop :=
forall (f:fn),
  FnInterface f i ->
  forall (v v':V),
    f v = Res v' ->
    IsA v' outT ->
    ~ IsA v notInT.
*)


(*  
Theorem a_neg_complete : forall a outT notInT,
    a_neg a outT = notInT ->
    forall notInT',
      ArrowInvNeg a outT notInT' ->
      notInT' <: (a_dom a) ->
      notInT' <: notInT.
*)
  
  
(* Interface Inversion Completeness *)
Lemma i_inv_neg_complete : forall i outT notInT,
      InterfaceInvNeg i outT notInT ->
      (notInT <: (i_dom i)) ->
      notInT <: i_inv_neg (i_powerset i) outT.
Proof.
  intros i. induction i as [[T1 T2] | [T1 T2] i' IH].
    (* (IBase (Arrow T1 T2)) *)
  {
    intros outT notInT Hint Hdom x Hx.
    eapply a_neg_complete; eauto; crush.
  }
    (* (ICons (Arrow T1 T2) i') *)
  {
    intros outT notInT Hint Hdom x Hx.
    destruct (IsEmpty_dec (tyAnd notInT T1)) as [Hn1 | Hn1].
    (* IsEmpty (tyAnd notInT T1) *)
    {
      assert (InterfaceInvNeg i' outT notInT) as IH'.
      {
        unfold InterfaceInvNeg in *.
        intros f Hfi' v v' Hres Hv' Hcontra.
        
        
      }
    }
    (* IsInhabited (tyAnd notInT T1) *)
    {
    }
    simpl in *.
    destruct (exists_FnInterface (ICons (Arrow T1 T2) i') outT)
      as [f [Hfi Hmaps]].
    unfold InterfaceInvNeg in *.
    assert (forall v' : V, f x = Res v' -> IsA v' outT -> ~ IsA x notInT)
      as Hfx. eauto.
    unfold a_neg. simpl.
    destruct (IsEmpty_dec (tyAnd T2 outT)) as [Hmt | Hnmt].
    (* IsA x (tyOr T1 (i_inv_neg i' outT)) *)
    {
      apply Hdom in Hx.
      destruct Hx as [x Hx | x Hx].
      left; auto.
      
    }
    (* IsA x (tyOr emptyTy (i_inv_neg i' outT)) *)
    {
      unfold MapsTo in Hmaps.

    }
  }

  
(* Interface Inversion Completeness *)
Lemma i_inv_complete : forall i outT inT,
    i_inv i outT = inT ->
    forall inT',
      InterfaceInv i outT inT' ->
      inT <: inT'.
Proof.
  intros i. induction i as [[T1 T2] | [T1 T2] i'].
  (* (IBase (Arrow T1 T2)) *)
  {
    intros outT inT Hinv inT' Hint x Hx.
    unfold InterfaceInv in *.
    unfold i_inv in *.
    rewrite <- Hinv in Hx.
    clear Hinv.
    destruct Hx as [HxIn HxNotIn].
    simpl in *.
    assert (forall inT',
               ArrowInv (Arrow T1 T2) outT inT' ->
               (a_pos (Arrow T1 T2) outT) <: inT')
      as HPCom
        by (eapply a_pos_complete; auto).
    assert (forall notInT',
               ArrowInvNeg (Arrow T1 T2) outT notInT' ->
               (notInT' <: (a_dom (Arrow T1 T2)) ->
                           notInT' <: (a_neg (Arrow T1 T2) outT)))
      as HNCom
        by (eapply a_neg_complete; auto).
    unfold a_pos in *.
    unfold a_neg in *.
    destruct (IsEmpty_dec (tyAnd (a_rng (Arrow T1 T2)) outT))
      as [Hmt | Hnmt].
    {
      assert False as impossible by (eapply no_empty_val; eauto).
      contradiction.
    }
    {
      simpl in *.
      destruct (exists_FnArrow T1 Hnmt)
        as [f [Hf Hex]].
      specialize Hex with x.
      destruct (Hex HxIn) as [v' [Hv' Hres]]. 
      assert (FnInterface f (IBase (Arrow T1 T2))) as  Hf' by crush.
      eapply Hint; eauto.
      inversion Hv'; auto.
    }
  }
  (* (ICons (Arrow T1 T2)) *)
  {
    unfold InterfaceInv.
    intros outT intT Hinv inT' Hint x Hx.
    unfold i_inv in *. simpl in *.
    rewrite <- Hinv in Hx.
    clear Hinv.
    destruct Hx as [HxIn HxNotIn].
    destruct HxIn as [x HxIn | x HxIn].
    (* IsA x (a_pos (Arrow T1 T2) outT) *)
    {
      assert (forall inT',
                 ArrowInv (Arrow T1 T2) outT inT' ->
                 (a_pos (Arrow T1 T2) outT) <: inT')
        as HPCom
          by (eapply a_pos_complete; auto).
      assert (forall notInT',
                 ArrowInvNeg (Arrow T1 T2) outT notInT' ->
                 (notInT' <: (a_dom (Arrow T1 T2)) ->
                             notInT' <: (a_neg (Arrow T1 T2) outT)))
        as HNCom
          by (eapply a_neg_complete; auto).
      unfold a_pos in *.
      unfold a_neg in *.
      simpl in *.
      destruct (IsEmpty_dec (tyAnd T2 outT))
        as [Hmt | Hnmt].
      (* Hmt: IsEmpty  (* (tyAnd T2 outT) *) *)
      {
        assert False as impossible by (eapply no_empty_val; eauto).
        contradiction.
      }
      (* Hnmt: IsInhabited  (* (tyAnd T2 outT) *) *)
      {
        rewrite tyOr_empty_l in HxNotIn.
        destruct (exists_FnInterface (ICons (Arrow T1 T2) i') outT)
          as [f [Hfi Hf]].
        assert (exists v' : V, IsA v' (tyAnd T2 outT) /\ f x = Res v')
          as Hex.
        {
          inversion Hfi; subst.
          eapply Hf; eauto.
        }
        destruct Hex as [y [Hy Hres]].
        eapply Hint; eauto.
        destruct Hy; auto.
      }
    }
    (* IsA x (i_inv_pos
                 (i_app (i_map (a_meet (Arrow T1 T2)) (i_powerset i'))
                    (i_powerset i')) outT) *)
    {
      (* BOOKMARK *)
    }

  
Admitted.

    
(* A disjunction of interfaces *)
Inductive dnf : Type :=
| DBase : interface -> dnf
| DCons : interface -> dnf -> dnf.

Fixpoint d_dom (d : dnf) : Ty :=
  match d with
  | DBase i => i_dom i
  | DCons i d' => tyAnd (i_dom i) (d_dom d')
  end.

Inductive FnDnf : fn -> dnf -> Prop :=
| FnDBase : forall f i,
    FnInterface f i ->
    FnDnf f (DBase i)
| FnDCons : forall f i d,
    FnInterface f i -> 
    FnDnf f (DCons i d)
| FnDRest : forall f i d,
    FnDnf f d -> 
    FnDnf f (DCons i d).


Fixpoint d_inv (d:dnf) (out:Ty) : Ty :=
  match d with
  | DBase i => i_inv i out
  | DCons i d' => tyOr (i_inv i out) (d_inv d' out)
  end. 

Definition DnfInv
           (d:dnf)
           (outT inT : Ty) : Prop :=
forall (f:fn),
  FnDnf f d ->
  forall (v v':V),
    IsA v (d_dom d) ->
    f v = Res v' ->
    IsA v' outT ->
    IsA v inT.


(* Dnf Inversion Soundness *)
Theorem d_inv_sound : forall d outT inT,
      d_inv d outT = inT ->
      DnfInv d outT inT.
Proof.
  Admitted.


(* Dnf Inversion Completeness *)
Theorem d_inv_complete : forall d outT inT,
    d_inv d outT = inT ->
    forall inT',
      DnfInv d outT inT' ->
      inT <: inT'.
Proof.
  Admitted.
