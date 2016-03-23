(*
  Cours "Typage et Analyse Statique"
  Université Pierre et Marie Curie
  Author: Manyanda Chitimbo �2016
  Original author: Antoine Miné 2015
*)


(* 
  Abstract interpreter by induction on the syntax.
  Parameterized by an abstract domain.
*)


open Abstract_syntax_tree
open Abstract_syntax_printer
open Domain
open Interpreter

module Trace_Interprete(D : DOMAIN) =
(struct
 	type t = D.t
	
	type key = 
		| TRUE
		| FALSE
		| BOT
	
	
  let filter (a:t) (e:bool_expr ext) (r:bool) : t =

    (* recursive exploration of the expression *)
    let rec doit a (e,x) r = match e with

    (* boolean part, handled recursively *)
    | AST_bool_unary (AST_NOT, e) -> 
        doit a e (not r)
    | AST_bool_binary (AST_AND, e1, e2) ->
        (if r then D.meet else D.join) (doit a e1 r) (doit a e2 r)
    | AST_bool_binary (AST_OR, e1, e2) -> 
        (if r then D.join else D.meet) (doit a e1 r) (doit a e2 r)
    | AST_bool_const b ->
        if b = r then a else D.bottom ()
          
    (* arithmetic comparison part, handled by D *)
    | AST_compare (cmp, (e1,_), (e2,_)) ->
        (* utility function to negate the comparison, when r=false *)
        let inv = function
        | AST_EQUAL         -> AST_NOT_EQUAL
        | AST_NOT_EQUAL     -> AST_EQUAL
        | AST_LESS          -> AST_GREATER_EQUAL
        | AST_LESS_EQUAL    -> AST_GREATER
        | AST_GREATER       -> AST_LESS_EQUAL
        | AST_GREATER_EQUAL -> AST_LESS
        in
        let cmp = if r then cmp else inv cmp in
        D.compare a e1 cmp e2

    in
    doit a e r
		
	(*TODO trace partitionning evaluation here*)	
	let rec eval_stat (a:t) ((s,ext):stat ext) : t = 
    let r = match s with    

    | AST_block (decl,inst) ->
        let a =
          List.fold_left
            (fun a ((_,v),_) -> D.add_var a v)
            a decl
        in
        let a = List.fold_left eval_stat a inst in
        List.fold_left
          (fun a ((_,v),_) -> D.del_var a v)
          a decl
        
    | AST_assign ((i,_),(e,_)) ->
        D.assign a i e
          
    | AST_if (e,s1,Some s2) ->
        let t = eval_stat (filter a e true ) s1 in
        let f = eval_stat (filter a e false) s2 in
        D.join t f
          
    | AST_if (e,s1,None) ->
        let t = eval_stat (filter a e true ) s1 in
        let f = filter a e false in
        D.join t f
          
    | AST_while (e,s) ->
        let rec fix (f:t -> t) (x:t) : t = 
          let fx = f x in
          if D.subset fx x then fx
          else fix f fx
        in
				let f x = if !loop_unrolling = 0 then (
					if !widen_delay = 0 then 
							let widened = D.widen a (eval_stat (filter x e true) s) in
							if !narrowing_value = 0 then widened 
							else (
									narrowing_value := !narrowing_value -1;
									D.narrow (eval_stat (filter x e true) s) widened 
							)
					else (
						widen_delay := !widen_delay - 1;
						D.join a (eval_stat (filter x e true) s)
					)) else ( 
						loop_unrolling := !loop_unrolling - 1;
						eval_stat (filter x e true) s
						) in 
         let inv = fix f a in 
					filter inv e false

    | AST_assert (e,p) ->
				let filtered = filter a (e,p) false in 
				if not (D.is_bottom filtered) then (error p "Assertion error.");
				filter a (e,p) true
    | AST_print l ->
        let l' = List.map fst l in
        Format.printf "%s: %a@\n"
          (string_of_extent ext) (fun fmt v -> D.print fmt a v) l';
        a
          
    | AST_HALT ->
        D.bottom ()
          
    in
    
    (* tracing, useful for debugging *)
    if !trace then 
      Format.printf "stat trace: %s: %a@\n" 
        (string_of_extent ext) D.print_all r;
    r

				
  let rec eval_prog (l:prog) : unit = ()

end : INTERPRETER)