(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2010     *)
(*   \VV/  **************************************************************)
(*    //   *   The HELM Project         /   The EU MoWGLI Project       *)
(*         *   University of Bologna                                    *)
(************************************************************************)
(*          This file is distributed under the terms of the             *)
(*           GNU Lesser General Public License Version 2.1              *)
(*                                                                      *)
(*                 Copyright (C) 2000-2004, HELM Team.                  *)
(*                       http://helm.cs.unibo.it                        *)
(************************************************************************)

let prooftreedtdname = "http://mowgli.cs.unibo.it/dtd/prooftree.dtd";;

let idref_of_id id = "v" ^ id;;

(* Transform a constr to an Xml.token Stream.t *)
(* env is a named context                      *)
(*CSC: in verita' dovrei "separare" le variabili vere e lasciarle come Var! *)
let constr_to_xml obj sigma env =
  let ids_to_terms = Hashtbl.create 503 in
  let constr_to_ids = Acic.CicHash.create 503 in
  let ids_to_father_ids = Hashtbl.create 503 in
  let ids_to_inner_sorts = Hashtbl.create 503 in
  let ids_to_inner_types = Hashtbl.create 503 in

  (* named_context holds section variables and local variables *)
  let named_context = Environ.named_context env  in
  (* real_named_context holds only the section variables *)
  let real_named_context = Environ.named_context (Global.env ()) in
  (* named_context' holds only the local variables *)
  let named_context' =
   List.filter (function n -> not (List.mem n real_named_context)) named_context
  in
  let idrefs =
   List.map
    (function x,_,_ -> idref_of_id (Names.string_of_id x)) named_context' in
  let rel_context = Sign.push_named_to_rel_context named_context' [] in
  let rel_env =
   Environ.push_rel_context rel_context
    (Environ.reset_with_named_context
	(Environ.val_of_named_context real_named_context) env) in
  let obj' =
   Term.subst_vars (List.map (function (i,_,_) -> i) named_context') obj in
  let seed = ref 0 in
   try
    let annobj =
     Cic2acic.acic_of_cic_context' false seed ids_to_terms constr_to_ids
      ids_to_father_ids ids_to_inner_sorts ids_to_inner_types rel_env
      idrefs sigma (Unshare.unshare obj') None
    in
     Acic2Xml.print_term ids_to_inner_sorts annobj
   with e ->
    Errors.anomaly
     ("Problem during the conversion of constr into XML: " ^
      Printexc.to_string e)
;;

let first_word s =
   try let i = String.index s ' ' in
       String.sub s 0 i
   with _ -> s
;;

let string_of_prim_rule x = match x with
  | Proof_type.Intro _-> "Intro"
  | Proof_type.Cut _ -> "Cut"
  | Proof_type.FixRule _ -> "FixRule"
  | Proof_type.Cofix _ -> "Cofix"
  | Proof_type.Refine _ -> "Refine"
  | Proof_type.Convert_concl _ -> "Convert_concl"
  | Proof_type.Convert_hyp _->"Convert_hyp"
  | Proof_type.Thin _ -> "Thin"
  | Proof_type.ThinBody _-> "ThinBody"
  | Proof_type.Move (_,_,_) -> "Move"
  | Proof_type.Order _ -> "Order"
  | Proof_type.Rename (_,_) -> "Rename"
  | Proof_type.Change_evars -> "Change_evars"

let
 print_proof_tree curi sigma pf proof_tree_to_constr
  proof_tree_to_flattened_proof_tree constr_to_ids
=
 let module PT = Proof_type in
 let module L = Logic in
 let module X = Xml in
  let ids_of_node node =
   let constr = Proof2aproof.ProofTreeHash.find proof_tree_to_constr node in
   try
    Some (Acic.CicHash.find constr_to_ids constr)
   with _ ->
Pp.msg_warning (Pp.(++) (Pp.str
"The_generated_term_is_not_a_subterm_of_the_final_lambda_term")
(Printer.pr_lconstr constr)) ;
    None
  in
  let rec aux node old_hyps =
   let of_attribute =
    match ids_of_node node with
       None -> []
     | Some id -> ["of",id]
   in
    match node with
       {PT.ref=Some(PT.Prim tactic_expr,nodes)} ->
         let tac = string_of_prim_rule tactic_expr in
         let of_attribute = ("name",tac)::of_attribute in
          if nodes = [] then
           X.xml_empty "Prim" of_attribute
          else
           X.xml_nempty "Prim" of_attribute
            (List.fold_left
              (fun i n -> [< i ; (aux n old_hyps) >]) [<>] nodes)

     | {PT.ref=Some(PT.Daimon,_)} ->
         X.xml_empty "Hidden_open_goal" of_attribute

     | {PT.ref=None;PT.goal=goal} ->
         X.xml_empty "Open_goal" of_attribute
     | {PT.ref=Some(PT.Decl_proof _, _)} -> failwith "TODO: xml and decl_proof"
  in
   [< X.xml_cdata "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n" ;
      X.xml_cdata ("<!DOCTYPE ProofTree SYSTEM \""^prooftreedtdname ^"\">\n\n");
      X.xml_nempty "ProofTree" ["of",curi] (aux pf [])
   >]
;;


(* Hook registration *)
(* CSC: debranched since it is bugged
Xmlcommand.set_print_proof_tree print_proof_tree;;
*)
