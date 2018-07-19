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

Definition a_meet (a1 a2 : arrow) : arrow :=
  match a1, a2 with
  | Arrow d1 r1, Arrow d2 r2 => Arrow (tyAnd d1 d2) (tyAnd r1 r2)
  end.
Hint Unfold a_meet.

Definition a_dom (a : arrow) : Ty :=
  match a with
  | Arrow t1 _ => t1
  end.
Hint Unfold a_dom.

Definition a_rng (a : arrow) : Ty :=
  match a with
  | Arrow _ t2 => t2
  end.
Hint Unfold a_rng.


Inductive res : Type :=
| Err : res (* invalid argument/type error *)
| Bot : res (* non-termination *)
| Res : V -> res. (* a value result *)
Hint Constructors res.

Definition fn := (V -> res).

Inductive FnArrow : fn -> arrow -> Prop :=
| FnA : forall T1 T2 f,
    (forall v,
        IsA v T1 ->
        (f v = Bot
         \/ (exists v', IsA v' T2 /\ f v = Res v'))) ->
    FnArrow f (Arrow T1 T2).
Hint Constructors FnArrow.

(* We cannot prove the axiom `exists_FnArrow` becase we are
   not including any defails about how fn's are constructed
   internally (i.e. we're not actually talking about the
   specific operational semantics) but it is trivial to see
   that this is true, since the language in Frisch et
   al. has a typecase and thus could check for input of type
   T1 and return the witness of type (T2 ∩ outT) when seeing
   a T1. *)
Axiom exists_FnArrow : forall T1 T2 outT,
    IsInhabited (tyAnd T2 outT) ->
    exists f,
      FnArrow f (Arrow T1 T2)
      /\ forall v, IsA v T1 ->
                   exists v', IsA v' (tyAnd T2 outT)
                              /\ f v = Res v'.


Ltac destruct_IsA :=
  match goal with
  | [H : IsA _ _ |- _] => destruct H
  end.

Definition a_inv_pos (a:arrow) (out:Ty) : Ty :=
  if (IsEmpty_dec (tyAnd (a_rng a) out))
  then emptyTy
  else (a_dom a).

Definition a_inv_neg (a:arrow) (out:Ty) : Ty :=
  if (IsEmpty_dec (tyAnd (a_rng a) out))
  then (a_dom a)
  else emptyTy.

Hint Unfold a_inv_pos a_inv_neg.

Definition ArrowInv 
           (a:arrow)
           (outT inT : Ty) : Prop :=
forall (f:fn),
  FnArrow f a ->
  forall (v v':V),
    IsA v (a_dom a) ->
    f v = Res v' ->
    IsA v' outT ->
    IsA v inT.

Definition ArrowInvNeg 
           (a:arrow)
           (outT notInT : Ty) : Prop :=
forall (f:fn),
  FnArrow f a ->
  forall (v v':V),
    f v = Res v' ->
    IsA v' outT ->
    ~ IsA v notInT.

Hint Unfold ArrowInv ArrowInvNeg.

Ltac same_Res :=
  match goal with
  | [H1 : ?f ?v = Res ?x , H2 : ?f ?v = Res ?y |- _] =>
    rewrite H1 in H2; inversion H2; subst; clear H2
  end.

Ltac inv_FnArrow :=
  match goal with
  | [H : FnArrow _ _ |- _] => inversion H; subst
  end.


(* Arrow Inversion Soundness *)
Lemma a_inv_pos_sound : forall a outT inT,
    a_inv_pos a outT = inT ->
    ArrowInv a outT inT.
Proof with crush.
  unfold ArrowInv.
  intros [T1 T2] outT inT Hinv f Hf v v' Hin Hfv Hout.
  unfold a_inv_pos in *. simpl in *. 
  destruct (IsEmpty_dec (tyAnd T2 outT)) as [Hmt | Hnmt]...
  inv_FnArrow.
  applyHinH...
  same_Res.
  assert (Inhabited V (tyAnd T2 outT)) as impossible...
  exists x...
Qed.

Lemma a_inv_neg_sound : forall a outT notInT,
    a_inv_neg a outT = notInT ->
    ArrowInvNeg a outT notInT.
Proof with crush.
  unfold ArrowInvNeg.
  intros [T1 T2] outT notInT Hinv f Hf v v' Hfv.
  unfold a_inv_neg in *. simpl in *. 
  destruct (IsEmpty_dec (tyAnd T2 outT)) as [Hmt | Hnmt]...
  (* ~ IsEmpty (tyAnd T2 outT) *)
  {
    apply Hmt. exists v'. split; crush.
    inv_FnArrow.
    applyHinH...
  }
  (* IsInhabited (tyAnd T2 outT) *)
  {
    eapply no_empty_val; eauto.
  }
Qed.
  
  
(* Arrow Inversion Completeness *)
Theorem a_inv_pos_complete : forall a outT inT,
    a_inv_pos a outT = inT ->
    forall inT',
      ArrowInv a outT inT' ->
      inT <: inT'.
Proof.
  intros [T1 T2] outT inT Hinveq inT' Hinv.
  unfold a_inv_pos in *. simpl in *.
  destruct (IsEmpty_dec (tyAnd T2 outT)) as [Hmt | Hnmt]; subst; crush.
  (* note T1 = inT *)
  intros x Hx.
  destruct (exists_FnArrow inT Hnmt)
    as [f [Hf Hex]].
  specialize Hex with x.
  assert (IsA x inT) as Hex' by assumption.
  apply Hex in Hex'. clear Hex.
  destruct Hex' as [v [Hv Hres]].
  unfold ArrowInv in *.
  apply (Hinv f Hf x v); crush.
  inversion Hv; crush.
Qed.

Theorem a_inv_neg_complete : forall a outT notInT,
    a_inv_neg a outT = notInT ->
    forall notInT',
      ArrowInvNeg a outT notInT' ->
      notInT' <: (a_dom a) ->
      notInT' <: notInT.
Proof.
  intros [T1 T2] outT notInT Hinv notInT' H' Hdom x Hx.
  unfold a_inv_neg in Hinv. simpl in *.
  unfold ArrowInvNeg in *.
  destruct (IsEmpty_dec (tyAnd T2 outT)) as [Hmt | Hnmt]; crush.
  assert False as impossible.
  {
    destruct (exists_FnArrow T1 Hnmt)
      as [f [Hf Hex]].
    specialize Hex with x.
    assert (IsA x T1) as Hex' by crush.
    apply Hex in Hex'. clear Hex.
    destruct Hex' as [v [Hv Hres]].
    apply (H' f Hf x v); crush.
    inversion Hv; crush.
  }
  crush.
Qed.  


Inductive interface : Type :=
| IBase: arrow -> interface
| ICons : arrow -> interface -> interface.
Hint Constructors interface.

Fixpoint i_dom (i : interface) : Ty :=
  match i with
  | IBase a => a_dom a
  | ICons a i' => tyOr (a_dom a) (i_dom i')
  end.
Hint Unfold i_dom.

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


(* Similar to `exists_FnArrow`, we cannot prove
   `exists_FnInterface` but it is safe to assume. *)
Axiom exists_FnInterface : forall i outT,
    exists f,
      forall T1 T2,
        InInterface (Arrow T1 T2) i ->
        FnArrow f (Arrow T1 T2)
        /\ (IsInhabited (tyAnd T2 outT) ->
            forall v, IsA v T1 ->
                      exists v', IsA v' (tyAnd T2 outT)
                                 /\ f v = Res v').
(* BOOKMARK *)

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


Fixpoint i_inv_pos (p: interface) (out:Ty) : Ty :=
  match p with
  | IBase a => (a_inv_pos a out)
  | ICons a p' => tyOr (a_inv_pos a out) (i_inv_pos p' out)
  end.
Hint Unfold i_inv_pos.

Fixpoint i_inv_neg (p: interface) (out:Ty) : Ty :=
  match p with
  | IBase a => (a_inv_neg a out)
  | ICons a p' => tyOr (a_inv_neg a out) (i_inv_neg p' out)
  end.
Hint Unfold i_inv_neg.


Definition i_inv (i:interface) (out:Ty) : Ty :=
  tyDiff (i_inv_pos (i_powerset i) out)
         (i_inv_neg (i_powerset i) out).
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


Lemma i_inv_pos_sound : forall i outT inT,
    i_inv_pos i outT = inT ->
    InterfaceInv i outT inT.
Proof with crush.
  intros i; induction i as [[T1 T2] | [T1 T2] i IHi].
  (* Case (IBase a) *)
  {
    unfold InterfaceInv.
    intros outT inT Hinv f Hint v v' Hv Hf Hv'.
    inv_FnInterface...
    inv_FnArrow.
    assert (IsA v T1) as temp; auto.
    applyIn temp...
    same_Res.
    eapply a_inv_pos_sound; eauto.
  }
  (* Case (ICons a i) *)
  {
    unfold InterfaceInv.
    intros outT inT Hinv f Hint v v' Hv Hf Hv'.
    crush.
    inv_FnInterface.
    inversion Hv; subst.
    (* IsA V (a_dom a) *)
    {
      left.
      inv_FnArrow.
      simpl in *.
      assert (IsA v T1) as H' by assumption.
      applyHinH... same_Res.
      unfold a_inv_pos.
      simpl.
      destruct (IsEmpty_dec (tyAnd T2 outT)) as [Hmt | Hnmt]; auto.
      (* IsEmpty (tyAnd T2 outT) *)
      {
        assert False as impossible.
        {
          eapply (empty_counterexample x _ Hmt); auto.
        }
        contradiction.
      }
    }
    (* IsA V (i_dom i) *)
    {
      right.
      specialize IHi with outT (i_inv_pos i outT).
      intuition.
      unfold InterfaceInv in *.
      eauto.
      Unshelve.
      crush.
    }
  }
Qed.

Lemma i_inv_neg_sound : forall i outT notInT,
    i_inv_neg i outT = notInT ->
    InterfaceInvNeg i outT notInT.
Proof with crush.
  intros i; induction i as [[T1 T2] | [T1 T2] i IHi].
  (* Case (IBase a) *)
  {
    unfold InterfaceInvNeg.
    intros outT notInT Hinv f Hint v v' hf Hv' Hcontra.
    subst. simpl in *.
    inv_FnInterface.
    eapply (a_inv_neg_sound outT); eauto.
  }
  (* Case (ICons a i) *)
  {
    unfold InterfaceInvNeg.
    intros outT notInT Hinv f Hint v v' hf Hv' Hcontra.
    simpl in *. subst.
    inv_FnInterface.
    destruct Hcontra.
    (* IsA v (a_inv_neg (Arrow T1 T2) outT) *)
    {
      unfold a_inv_neg in *. simpl in *.
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
      assert (InterfaceInvNeg i outT (i_inv_neg i outT)) as Hi; auto.
      destruct Hi with f x v'; auto.
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
  rewrite <- Hinv. constructor.
  (* Show: IsA v (i_inv_pos i' outT) *)
  {
    assert (InterfaceInv i' outT (i_inv_pos i' outT)) as Hpos.
    {
      specialize i_inv_pos_sound with i' outT (i_inv_pos i' outT); eauto.
    }
    eapply Hpos; eauto.
    subst.
    rewrite <- (i_powerset_dom i).
    assumption.
  }
  (* Show: ~ IsA v (i_inv_neg i' outT) *)
  {
    intros Hcontra.
    assert (InterfaceInvNeg i' outT (i_inv_neg i' outT)) as Hneg.
    {
      specialize i_inv_neg_sound with i' outT (i_inv_neg i' outT); eauto.
    }
    eapply Hneg; eauto.
  }
Qed.


  
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
    destruct Hx as [HxIn HxNotIn].
    simpl in *.
    assert (forall inT',
               ArrowInv (Arrow T1 T2) outT inT' ->
               (a_inv_pos (Arrow T1 T2) outT) <: inT')
      as HPCom
        by (eapply a_inv_pos_complete; auto).
    assert (forall notInT',
               ArrowInvNeg (Arrow T1 T2) outT notInT' ->
               (notInT' <: (a_dom (Arrow T1 T2)) ->
                           notInT' <: (a_inv_neg (Arrow T1 T2) outT)))
      as HNCom
        by (eapply a_inv_neg_complete; auto).
    unfold a_inv_pos in *.
    unfold a_inv_neg in *.
    destruct (IsEmpty_dec (tyAnd (a_rng (Arrow T1 T2)) outT)) as [Hmt | Hex].
    {
      assert False as impossible by (eapply no_empty_val; eauto).
      contradiction.
    }
    {
      simpl in *.
      destruct Hex as [y Hy].
      destruct Hy as [y Hy1 Hy2].
      remember (fun (_:V) => Res y) as f.
      (* i.e., f is a constant function to (T2 ∩ outT) *)
      assert (FnInterface f (IBase (Arrow T1 T2))) as  Hf.
      {
        constructor. constructor.
        intros v Hv.
        right. exists y. crush.
      }
      eapply Hint; eauto. crush. 
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
    (* IsA x (a_inv_pos (Arrow T1 T2) outT) *)
    {
    assert (forall inT',
               ArrowInv (Arrow T1 T2) outT inT' ->
               (a_inv_pos (Arrow T1 T2) outT) <: inT')
      as HPCom
        by (eapply a_inv_pos_complete; auto).
    assert (forall notInT',
               ArrowInvNeg (Arrow T1 T2) outT notInT' ->
               (notInT' <: (a_dom (Arrow T1 T2)) ->
                           notInT' <: (a_inv_neg (Arrow T1 T2) outT)))
      as HNCom
        by (eapply a_inv_neg_complete; auto).
    unfold a_inv_pos in *.
    unfold a_inv_neg in *.
    destruct (IsEmpty_dec (tyAnd (a_rng (Arrow T1 T2)) outT)) as [Hmt | Hex].
    {
      assert False as impossible by (eapply no_empty_val; eauto).
      contradiction.
    }
    {
      simpl in *.
      destruct Hex as [y Hy].
      destruct Hy as [y Hy1 Hy2].
      remember (fun (_:V) => Res y) as f.
      (* i.e., f is a constant function to (T2 ∩ outT) *)
      assert (FnInterface f (IBase (Arrow T1 T2))) as  Hf.
      {
        constructor. constructor.
        intros v Hv.
        right. exists y. crush.
      }
      eapply Hint; eauto. crush. 
    }

    (* BOOKMARK *)
    }
    (* IsA x (i_inv_pos
                 (i_app (i_map (a_meet (Arrow T1 T2)) (i_powerset i'))
                    (i_powerset i')) outT) *)

  
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
