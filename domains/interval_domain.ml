(*
  Cours "Typage et Analyse Statique"
  Universit√© Pierre et Marie Curie
  Author: Manyanda Chitimbo ©2016
*)

(* 
   The interval domain
 *)
open Abstract_syntax_tree
open Value_domain
  
module Intervals = (struct
  (* types *)
  (* ***** *)

  (* type of abstract values *)
	type t = 
		| Interval of Q.t * Q.t (* x = (a,b) a range of values from a to b*)
    | BOT         (* the set is empty (not reachable) *)
    | TOP         (* the set of all integers (not constant)  *)

		
  (* interface implementation *)
  (* ************************ *)

  (* unrestricted value *)
  let top = TOP

  (* bottom value *)
  let bottom = BOT

	let make_q v = Q.make v Z.one
  (* constant *)
  let const c = let q =  make_q c in Interval (q, q)

  (* interval*)
  let rand x y =
    if x > y then BOT
    else Interval (make_q x,make_q y)	

	 (* set-theoretic operations *)
  
  let join i i1 = match i,i1 with
  | BOT,x | x,BOT -> x
  | Interval (a,b), Interval (c,d) -> (
		let min_ = Q.min a c 
		and max_ = Q.max b d 
		in Interval (min_, max_)
		)
  | _ -> TOP

  let meet i i1 = match i,i1 with
  | TOP,x | x,TOP -> x
  | Interval (a,b), Interval (c,d) -> (
		let max_ = Q.max a c 
		and min_ = Q.min b d  
		in if Q.gt max_ min_ then BOT 
		else Interval (max_,min_)
		)
  | _ -> BOT


  (* arithmetic operations *)

  let neg i = match i with
	| Interval(a,b) -> Interval (Q.neg b, Q.neg a)
	| _ -> BOT

  let add i i1 = 
		match i,i1 with
		| Interval(a,b), Interval(c,d) -> Interval((Q.add a c), (Q.add b d))
		| _ -> BOT

  let sub i i1 = 
		match i,i1 with
		| Interval(a,b), Interval(c,d) -> Interval((Q.sub a c), (Q.add b d))
		| _ -> BOT
		

	let make_mul a b c d = 
		let r1 = Q.mul a c and r2 = Q.mul a d 
		and r3 = Q.mul b c and r4 = Q.mul b d 
		in let min_ = Q.min (Q.min r1 r2) (Q.min r3 r4) 
		and max_ = Q.max (Q.max r1 r2) (Q.max r3 r4) 
		in Interval(min_,max_)
	 
  let mul i i1 = 
		match i,i1 with
		| Interval(a,b), Interval(c,d) -> make_mul a b c d
		| _ -> BOT
	
	let make_div i i1 =
		match i,i1 with
		| Interval(a,b), Interval(c,d) ->   
		let r1 = Q.min (Q.div a c) (Q.div a d) and 
				r2 = Q.max (Q.div b c) (Q.div d b) and
				r3 = Q.min (Q.div b c) (Q.div b d) and 
				r4 = Q.max (Q.div a c) (Q.div a d) in 
				
				if (Q.geq c Q.one) then Interval(r1,r2)
				else (
					if (Q.geq Q.minus_one d) then Interval (r3,r4)
					else BOT
					)
		| _ -> BOT

  let div i i1 =
    match i,i1 with
		| Interval(a,b), Interval(c,d) -> (
			let pos = Interval (Q.one, Q.inf) and neg_ = Interval (Q.minus_inf,Q.minus_one) 
			in let first = meet i1 pos and second = meet i1 neg_
			in join (make_div i first) (make_div i second)
			)
	 	| _ -> BOT
			
	let erem a b = 
		if not (Q.is_real a) then a 
		else (
			if not (Q.is_real b) then b
			else
				make_q (Z.erem (Q.to_bigint a) (Q.to_bigint b)) 
			)
			
	(* Determines interval after the modulo operation. TODO test and improves this*)	
	let make_mod i i2 = 
		match i,i2 with
		| Interval(a,b), Interval(c,d) -> 
			let r1 = erem a c and r2 = erem a d 
			and r3 = erem b c and r4 = erem b d 
			in let min_ = Q.min (Q.min r1 r2) (Q.min r3 r4) 
			and max_ = Q.max (Q.max r1 r2) (Q.max r3 r4) 
			in (
					let res = Interval(min_,max_) 
					and head = Q.add a (Q.sub c r1) 
					and head2 =	Q.add a (Q.sub d r2)
					in let res2 = (if Q.geq b head then Interval(Q.zero,(Q.sub c Q.one)) else res) 
					and res3 = (if Q.geq b head2 then Interval(Q.zero,(Q.sub d Q.one)) else res) in 
					join res (join res2 res3)		
			)
		| _ -> BOT

					 					
	(* TODO see make_mod*)
  let modulo i i1 =  
		match i,i1 with
		| Interval(a,b), Interval(c,d) -> (
			let pos = Interval (Q.one, Q.inf) and neg_ = Interval (Q.minus_inf,Q.minus_one) 
			in let first = meet i1 pos and second = meet i1 neg_
			in join (make_mod i first) (make_mod i second)
			)
		| _ -> BOT
		
  let widen i i1 = 
		match i,i1 with
		| Interval(a,b), Interval(c,d) -> 
			let min_ = if Q.gt c a then a else Q.minus_inf
			and max_ = if Q.geq b d then b else Q.inf
			in Interval(min_,max_)
		| BOT,x | x,BOT -> x
		| TOP,x | x,TOP -> TOP

	(* TODO refine this and add it to interpreter.*)
	let narrow i i1 = 
		match i,i1 with
		| Interval(a,b), Interval(c,d) -> 
			let min_ = if Q.equal a Q.minus_inf then c else a
			and max_ = if Q.equal b Q.inf then d else b
			in Interval(min_,max_)
		| BOT,x | x,BOT -> x
		| TOP,x | x,TOP -> TOP 

  (* subset inclusion of concretizations *)
  let subset i i1 = match i,i1 with
  | BOT,_ | _,TOP -> true
  | Interval (a,b), Interval (c,d) -> Q.geq a c && Q.geq d b
  | _ -> false

  (* check the emptyness of the concretization *)
  let is_bottom a =
    a=BOT
		
	(* TODO *)	
  let eq a b = if subset a b || subset b a then a,b else BOT,BOT

  let neq a b =
    match a,b with
		| Interval (x,x1), Interval (y,y1) -> if subset a b || subset b a then BOT,BOT else a,b
		| BOT,x | x,BOT -> x,BOT
		| _ -> a,b
    	  
  let geq a b = match a,b with
		| Interval (x,x1), Interval (y,y1) ->  if (Q.geq x1 y) then a,b else BOT,BOT
		| BOT,x | x,BOT -> x,BOT
		| _ -> a,b
      
  let gt a b =
    match a,b with
		| Interval (x,x1), Interval (y,y1) -> if (Q.gt x1 y) then a,b else BOT,BOT
		| BOT,x | x,BOT -> x,BOT
		| _ -> a,b


  (* prints abstract element *)
  let print fmt x = match x with
  | BOT -> Format.fprintf fmt "bottom"
  | TOP -> Format.fprintf fmt "top"
  |Interval (x,x1) -> Format.fprintf fmt "{%s}" ((Q.to_string x) ^ "," ^ (Q.to_string x1))


  (* operator dispatch *)
        
  let unary x op = match op with
  | AST_UNARY_PLUS  -> x
  | AST_UNARY_MINUS -> neg x

  let binary x y op = match op with
  | AST_PLUS     -> add x y
  | AST_MINUS    -> sub x y
  | AST_MULTIPLY -> mul x y
  | AST_DIVIDE   -> div x y
	| AST_MODULO   -> modulo x y

  let compare x y op = match op with
  | AST_EQUAL         -> eq x y
  | AST_NOT_EQUAL     -> neq x y
  | AST_GREATER_EQUAL -> geq x y
  | AST_GREATER       -> gt x y
  | AST_LESS_EQUAL    -> let y',x' = geq y x in x',y'
  | AST_LESS          -> let y',x' = gt y x in x',y'
        


  let bwd_unary x op r = match op with
  | AST_UNARY_PLUS  -> meet x r
  | AST_UNARY_MINUS -> meet x (neg r)

        
  let bwd_binary x y op r = match op with

  | AST_PLUS ->     
      meet x (sub r y), meet y (sub r x)

  | AST_MINUS ->
      meet x (add y r), meet y (sub y r)
        
  | AST_MULTIPLY ->
     let r1 = div r y and r2 = div r x in
		 	 (meet x r1), (meet y r2)			
				
  | AST_DIVIDE ->
			let d = Interval((Q.neg Q.one), Q.one) in 
			let s = add r d in (
				let u = join (div x s) (const Z.zero) in
					(meet x (mul s y), meet y u)
				)
				
	| AST_MODULO ->
      if (is_bottom r ) then x, (const Z.zero) else x,y
					      
      
end : VALUE_DOMAIN)

    
