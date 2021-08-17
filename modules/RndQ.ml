module RndQ = struct
(* Module permettant de cr�er une file al�atoire : chaque �l�ment
� un certain poids qui d�termine la probabilit� qu'il a d'�tre tir� *)

    exception Empty

    type 'a t = {mutable size: int; content : ('a * float) array; mutable tot : float}
    (** [size], la taille actuelle de la file, [content] une array dont les [size] premiers �l�ments
    repr�sentent les �l�ments restant dans la file avec leur probabilit�, [tot] est la somme des probabilit�s*)

    let simple_create size arr =
        {size; content = Array.map (fun x -> x, 1.) arr; tot = float_of_int size}
    (* Cr�er une file al�atoire contenant les [size] premiers �l�ments de [arr], o� tous les �l�ments
    ont les m�mes chances de sortir *)

    let create size arr weights = let tot = Array.fold_left (+.) 0. weights in
        {size; content = Array.mapi (fun i x -> x, weights.(i)) arr; tot}
    (* Cr�er une file al�atoire contenant les [size] premiers �l�ments de [arr] o� les chances de sortir
    d'un �l�ment de arr est pond�r� par l'�l�ment de m�me index de [weights] *)

    let is_empty q = q.size = 0
    (* Renvoie true si la file est vide *)

    let get_length q = q.size
    (* Renvoie la taille de la file *)

    let take q =
    (* Selectionne al�atoirement un �l�ment *)
        if q.size = 0 then raise Empty else
        let rec aux k acc = if k >= q.size - 1 then k else (
            let acc = acc -. let _, p = q.content.(k) in p in
                    if acc < 1e-10 then k else aux (k+1) acc
                )
        in
        let i = aux  0 @@ Random.float 1. *. q.tot  in
        (* [i] l'index selectionn� al�atoirement *)
            let res, p as r = q.content.(i) in
                q.content.(i) <- q.content.(q.size - 1);
                (* l'�l�ment i s�lectionn� est remplac� par le dernier �l�ment de la file *)
                q.content.(q.size - 1) <- r;
                (* On conserve l'�l�ment selectionn� dans l'array mais il ne fait plus partie de la file.
                On le conserve afin de pouvoir r�utiliser la file si besoin *)
                q.size <- q.size - 1;
                (* taille r�duite de 1 *)
                q.tot <- q.tot -. p;
                (* Poids total r�duit de la probabilit� de l'�l�ment choisi *)
                res

    let tot_empty q =
        Array.init q.size (fun _ -> take q)
    (* Cr�er une array contenant les �l�ments restant dans la file, dans un ordre al�atoire. *)

    let change_weights f q =
        let tot = ref 0. in
        for i = 0 to q.size - 1 do
            let x, w = q.content.(i)
            in
            let new_w = f w x in
                q.content.(i) <- (x, new_w);
                tot := !tot +. new_w
        done;
        q.tot <- !tot
    (* change les poids des diff�rents �l�ments selon f *)

    let reset q =
    (* Remet tous les �l�ments d�j� tir�s dans la file *)
        q.size <- Array.length q.content;
        q.tot <- Array.fold_left (fun acc (_,w) -> acc +. w) 0. q.content

end;;
module Readertsp = struct
    let open_tsp tsp_name =
        let city_count = Scanf.sscanf tsp_name "%[^0-9]%d" (fun _ c -> c)
        in
        let cities = Array.make city_count (0., 0.)
        in
        let fill = let i = ref 0 in
            fun x -> cities.(!i) <- x; incr i
        in
        let ic = open_in  @@
            Printf.sprintf "C:/Users/Clement/Documents/prepa/tipe/ocaml-tsp/tsp/%s.tsp" tsp_name
        in
        let rec loop started = try (let s = String.trim @@ input_line ic in
            if started then (
                let x,y = Scanf.sscanf s "%d %f %f" (fun _ x y -> (x, y))
                in
                fill (x,y);
                loop true
            ) else loop ("NODE_COORD_SECTION" = s)
            ) with _ -> ();
        in loop false;
        city_count, cities

    let open_path tsp_name =
        let city_count = Scanf.sscanf tsp_name "%[^0-9]%d" (fun _ c -> c)
        in
        let path = Array.make city_count 0
        in
        let fill = let i = ref 0 in
            fun x -> path.(!i) <- x-1; incr i
        in
        let ic = open_in  @@
            Printf.sprintf "C:/Users/Clement/Documents/prepa/tipe/ocaml-tsp/tsp/%s.opt.tour" tsp_name
        in
        let rec loop started = try (let s = String.trim @@ input_line ic in
            if started then (
                List.iter fill @@ List.map int_of_string @@ String.split_on_char ' ' s;
               loop true
            ) else loop ("TOUR_SECTION" = s)
            ) with _ -> ();
        in loop false;
        path

end;;
module Basetsp = struct
    let dists cities =
        let dist (c1x,c1y) (c2x,c2y) =
            int_of_float (0.5 +. sqrt ((c1x -. c2x)*.(c1x -. c2x) +. (c1y -. c2y)*. (c1y -. c2y)))
        in
        let city_count = Array.length cities in
        let adj_matrix = Array.init city_count (fun i -> Array.init city_count (fun j -> dist cities.(i) cities.(j)))
        in
        fun c1 c2 -> adj_matrix.(c1).(c2)
    let path_length eval path =
        let s = ref 0 in
        for i = 0 to Array.length path - 2 do
            s := !s + eval path.(i) path.(i+1)
        done;
        !s + eval path.(0) path.(Array.length path - 1)

    let best_path_length config eval =
        let path = Readertsp.open_path config in
        path_length eval path
end;;
module Showtsp = struct
    open Graphics
    type parameters = {mutable height: int; mutable width: int; mutable city_size: int}

    let params = {height=600; width=600; city_size=10}

    let coordToScreen (maxX, maxY) (x,y) =
           let a,b = float_of_int params.width *. 0.1 +. 0.8 *. float_of_int params.width *. x /. maxX,
            float_of_int params.height *. 0.1 +. 0.8 *. float_of_int params.height *. y /. maxY
        in int_of_float a, int_of_float b

    let show_cities cities =
        open_graph @@ Printf.sprintf "%dx%d" params.width params.height;
        clear_graph();
        set_line_width 1;
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities in
        Array.iteri (fun i (x,y) ->  set_color red; fill_circle x y params.city_size;set_text_size 20;set_color black;
                    moveto x y; draw_string @@ string_of_int i) @@ Array.map (coordToScreen (maxX, maxY)) cities

    let show_solution cities sol =
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities
        in
        let movetoT (x,y)= moveto x y
        in
        let coord = coordToScreen (maxX, maxY)
        in
        let lineto_city city = let x,y = coord cities.(city) in lineto x y
        in
        show_cities cities;
        set_line_width 3;
        set_color black;
        movetoT @@ coord cities.(sol.(0)) ;
        for k = 1 to Array.length sol - 1 do
            lineto_city sol.(k);
        done;
        lineto_city sol.(0)
        
    let show_solution_list cities sol =
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities
        in
        let movetoT (x,y)= moveto x y
        in
        let coord = coordToScreen (maxX, maxY)
        in
        let lineto_city city = let x,y = coord cities.(city) in lineto x y
        in
        show_cities cities;
        set_line_width 3;
        set_color black;
        let x :: xs = sol in 
            
        movetoT @@ coord cities.(x);
        List.iter lineto_city xs;
        lineto_city x
    let show_best_path config =
        let _, cities = Readertsp.open_tsp config in
        show_solution cities (Readertsp.open_path config)
    
end;;
module TwoOpt = struct
    let invertPath i j path =
        for k = 0 to (j - i)/2 - 1 do
             let t = path.(i+1+k) in
             path.(i+1+k) <- path.(j-k);
             path.(j-k) <- t;
         done
    let opt_best ?(debug = false) ?(maxi = -1) eval path =
        let bound = Array.length path in

        let rec loop k =
            let diff = ref 0 in
            let minI, minJ = ref 0, ref 0 in
                for i = 0 to bound - 4 do
                    for j = i+2 to bound - 1 - max 0 (1-i) do
                        let d = eval path.(i) path.(j) + eval path.(i+1) path.((j+1) mod bound)
                        - eval path.(i) path.(i+1) - eval path.(j) path.((j+1) mod bound)
                        in
                        if d < !diff then (
                            diff := d;
                            minI := i;
                            minJ := j
                        )
                    done
                done;
            if !diff < 0 then (
                invertPath !minI !minJ path;
                if debug then Printf.printf "\ninverted %d and %d" !minI !minJ;
                if k < maxi || maxi < 0 then loop (k+1)
            )
        in loop 1

    let opt_fast ?(debug = false) ?(maxi = -1) eval path =
        let bound = Array.length path in
        let rec rec_while i = (i < maxi || maxi < 0) &&
            not (loop1 0) && rec_while (i+1)
        and loop1 i = i >= bound - 4 || (loop2 i (i+2) && loop1 (i+1))
        and loop2 i j = j >= bound - max 0 (1-i)  || (
            let diff = eval path.(i) path.(j) + eval path.(i+1) path.((j+1) mod bound)
                                   - eval path.(i) path.(i+1) - eval path.(j) path.((j+1) mod bound)  in
            if diff < 0 then (
                invertPath i j path;
                if debug then Printf.printf "\ninverted %d and %d, diff : %d" i j diff;
                false
            ) else true
        ) && loop2 i (j+1)
        in
        let _ = rec_while 0 in ()

    type random_creation = Roulette | Random

    let weight_update eval last q = function
        | Random -> ()
        | Roulette -> RndQ.change_weights (fun _ x -> 1. /. float_of_int(eval x last)) q

    let random_path q eval mode city_count =
        Array.init city_count (
            fun _ -> let v = RndQ.take q in
                weight_update eval v q mode;
                v
        )

    let iter_two_opt n eval city_count rnd_mode =
        let arr = Array.init city_count (Fun.id) in
        let q = RndQ.simple_create city_count arr in
        let best_len = ref max_int in
        let best_path = Array.make city_count (-1) in
        for _ = 1 to n do
            let path = random_path q eval rnd_mode city_count in
            opt_fast eval path;
            let len = Basetsp.path_length eval path in
            if len < !best_len then (
                best_len := len;
                for i = 0 to city_count -1 do
                    best_path.(i) <- path.(i)
                done
            );
            RndQ.reset q

        done;
        best_path

end;;
module Primalg = struct
    let primalg eval city_count =
        let init_visited = IntSet.singleton 0 in
        let init_visit =
            let rec aux1 i acc =
            if i < city_count then aux1 (i + 1) (IntSet.add i acc) else acc
            in aux1 1 IntSet.empty
        in
        let rec aux to_visit visited score =
            if not @@ IntSet.is_empty to_visit then (
                let added = ref (-1) in
                let mini = ref max_int in
                IntSet.iter (fun c1 ->
                    IntSet.iter (fun c2 ->
                        let len = eval c1 c2 in
                        if len < !mini then (
                            mini := len;
                            added := c1
                        )) visited) to_visit;
                let new_to_visit = IntSet.remove !added to_visit
                in
                let new_visited = IntSet.add !added visited
                in
                aux new_to_visit new_visited (score +  !mini)
            ) else (
                score
            )
        in
        aux init_visit init_visited 0
end;;

module Readertsp = struct
    let open_tsp tsp_name =
        let city_count = Scanf.sscanf tsp_name "%[^0-9]%d" (fun _ c -> c)
        in
        let cities = Array.make city_count (0., 0.)
        in
        let fill = let i = ref 0 in
            fun x -> cities.(!i) <- x; incr i
        in
        let ic = open_in  @@
            Printf.sprintf "C:/Users/Clement/Documents/prepa/tipe/ocaml-tsp/tsp/%s.tsp" tsp_name
        in
        let rec loop started = try (let s = String.trim @@ input_line ic in
            if started then (
                let x,y = Scanf.sscanf s "%d %f %f" (fun _ x y -> (x, y))
                in
                fill (x,y);
                loop true
            ) else loop ("NODE_COORD_SECTION" = s)
            ) with _ -> ();
        in loop false;
        city_count, cities

    let open_path tsp_name =
        let city_count = Scanf.sscanf tsp_name "%[^0-9]%d" (fun _ c -> c)
        in
        let path = Array.make city_count 0
        in
        let fill = let i = ref 0 in
            fun x -> path.(!i) <- x-1; incr i
        in
        let ic = open_in  @@
            Printf.sprintf "C:/Users/Clement/Documents/prepa/tipe/ocaml-tsp/tsp/%s.opt.tour" tsp_name
        in
        let rec loop started = try (let s = String.trim @@ input_line ic in
            if started then (
                List.iter fill @@ List.map int_of_string @@ String.split_on_char ' ' s;
               loop true
            ) else loop ("TOUR_SECTION" = s)
            ) with _ -> ();
        in loop false;
        path

end;;
module Basetsp = struct
    let dists cities =
        let dist (c1x,c1y) (c2x,c2y) =
            int_of_float (0.5 +. sqrt ((c1x -. c2x)*.(c1x -. c2x) +. (c1y -. c2y)*. (c1y -. c2y)))
        in
        let city_count = Array.length cities in
        let adj_matrix = Array.init city_count (fun i -> Array.init city_count (fun j -> dist cities.(i) cities.(j)))
        in
        fun c1 c2 -> adj_matrix.(c1).(c2)
    let path_length eval path =
        let s = ref 0 in
        for i = 0 to Array.length path - 2 do
            s := !s + eval path.(i) path.(i+1)
        done;
        !s + eval path.(0) path.(Array.length path - 1)

    let best_path_length config eval =
        let path = Readertsp.open_path config in
        path_length eval path
end;;
module Showtsp = struct
    open Graphics
    type parameters = {mutable height: int; mutable width: int; mutable city_size: int}

    let params = {height=600; width=600; city_size=10}

    let coordToScreen (maxX, maxY) (x,y) =
           let a,b = float_of_int params.width *. 0.1 +. 0.8 *. float_of_int params.width *. x /. maxX,
            float_of_int params.height *. 0.1 +. 0.8 *. float_of_int params.height *. y /. maxY
        in int_of_float a, int_of_float b

    let show_cities cities =
        open_graph @@ Printf.sprintf "%dx%d" params.width params.height;
        clear_graph();
        set_line_width 1;
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities in
        Array.iteri (fun i (x,y) ->  set_color red; fill_circle x y params.city_size;set_text_size 20;set_color black;
                    moveto x y; draw_string @@ string_of_int i) @@ Array.map (coordToScreen (maxX, maxY)) cities

    let show_solution cities sol =
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities
        in
        let movetoT (x,y)= moveto x y
        in
        let coord = coordToScreen (maxX, maxY)
        in
        let lineto_city city = let x,y = coord cities.(city) in lineto x y
        in
        show_cities cities;
        set_line_width 3;
        set_color black;
        movetoT @@ coord cities.(sol.(0)) ;
        for k = 1 to Array.length sol - 1 do
            lineto_city sol.(k);
        done;
        lineto_city sol.(0)
        
    let show_solution_list cities sol =
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities
        in
        let movetoT (x,y)= moveto x y
        in
        let coord = coordToScreen (maxX, maxY)
        in
        let lineto_city city = let x,y = coord cities.(city) in lineto x y
        in
        show_cities cities;
        set_line_width 3;
        set_color black;
        let x :: xs = sol in 
            
        movetoT @@ coord cities.(x);
        List.iter lineto_city xs;
        lineto_city x
    let show_best_path config =
        let _, cities = Readertsp.open_tsp config in
        show_solution cities (Readertsp.open_path config)
    
end;;
module TwoOpt = struct
    let invertPath i j path =
        for k = 0 to (j - i)/2 - 1 do
             let t = path.(i+1+k) in
             path.(i+1+k) <- path.(j-k);
             path.(j-k) <- t;
         done
    let opt_best ?(debug = false) ?(maxi = -1) eval path =
        let bound = Array.length path in

        let rec loop k =
            let diff = ref 0 in
            let minI, minJ = ref 0, ref 0 in
                for i = 0 to bound - 4 do
                    for j = i+2 to bound - 1 - max 0 (1-i) do
                        let d = eval path.(i) path.(j) + eval path.(i+1) path.((j+1) mod bound)
                        - eval path.(i) path.(i+1) - eval path.(j) path.((j+1) mod bound)
                        in
                        if d < !diff then (
                            diff := d;
                            minI := i;
                            minJ := j
                        )
                    done
                done;
            if !diff < 0 then (
                invertPath !minI !minJ path;
                if debug then Printf.printf "\ninverted %d and %d" !minI !minJ;
                if k < maxi || maxi < 0 then loop (k+1)
            )
        in loop 1

    let opt_fast ?(debug = false) ?(maxi = -1) eval path =
        let bound = Array.length path in
        let rec rec_while i = (i < maxi || maxi < 0) &&
            not (loop1 0) && rec_while (i+1)
        and loop1 i = i >= bound - 4 || (loop2 i (i+2) && loop1 (i+1))
        and loop2 i j = j >= bound - max 0 (1-i)  || (
            let diff = eval path.(i) path.(j) + eval path.(i+1) path.((j+1) mod bound)
                                   - eval path.(i) path.(i+1) - eval path.(j) path.((j+1) mod bound)  in
            if diff < 0 then (
                invertPath i j path;
                if debug then Printf.printf "\ninverted %d and %d, diff : %d" i j diff;
                false
            ) else true
        ) && loop2 i (j+1)
        in
        let _ = rec_while 0 in ()

    type random_creation = Roulette | Random

    let weight_update eval last q = function
        | Random -> ()
        | Roulette -> RndQ.change_weights (fun _ x -> 1. /. float_of_int(eval x last)) q

    let random_path q eval mode city_count =
        Array.init city_count (
            fun _ -> let v = RndQ.take q in
                weight_update eval v q mode;
                v
        )

    let iter_two_opt n eval city_count rnd_mode =
        let arr = Array.init city_count (Fun.id) in
        let q = RndQ.simple_create city_count arr in
        let best_len = ref max_int in
        let best_path = Array.make city_count (-1) in
        for _ = 1 to n do
            let path = random_path q eval rnd_mode city_count in
            opt_fast eval path;
            let len = Basetsp.path_length eval path in
            if len < !best_len then (
                best_len := len;
                for i = 0 to city_count -1 do
                    best_path.(i) <- path.(i)
                done
            );
            RndQ.reset q

        done;
        best_path

end;;
module Primalg = struct
    let primalg eval city_count =
        let init_visited = IntSet.singleton 0 in
        let init_visit =
            let rec aux1 i acc =
            if i < city_count then aux1 (i + 1) (IntSet.add i acc) else acc
            in aux1 1 IntSet.empty
        in
        let rec aux to_visit visited score =
            if not @@ IntSet.is_empty to_visit then (
                let added = ref (-1) in
                let mini = ref max_int in
                IntSet.iter (fun c1 ->
                    IntSet.iter (fun c2 ->
                        let len = eval c1 c2 in
                        if len < !mini then (
                            mini := len;
                            added := c1
                        )) visited) to_visit;
                let new_to_visit = IntSet.remove !added to_visit
                in
                let new_visited = IntSet.add !added visited
                in
                aux new_to_visit new_visited (score +  !mini)
            ) else (
                score
            )
        in
        aux init_visit init_visited 0
end;;

module Readertsp = struct
    let open_tsp tsp_name =
        let city_count = Scanf.sscanf tsp_name "%[^0-9]%d" (fun _ c -> c)
        in
        let cities = Array.make city_count (0., 0.)
        in
        let fill = let i = ref 0 in
            fun x -> cities.(!i) <- x; incr i
        in
        let ic = open_in  @@
            Printf.sprintf "C:/Users/Clement/Documents/prepa/tipe/ocaml-tsp/tsp/%s.tsp" tsp_name
        in
        let rec loop started = try (let s = String.trim @@ input_line ic in
            if started then (
                let x,y = Scanf.sscanf s "%d %f %f" (fun _ x y -> (x, y))
                in
                fill (x,y);
                loop true
            ) else loop ("NODE_COORD_SECTION" = s)
            ) with _ -> ();
        in loop false;
        city_count, cities

    let open_path tsp_name =
        let city_count = Scanf.sscanf tsp_name "%[^0-9]%d" (fun _ c -> c)
        in
        let path = Array.make city_count 0
        in
        let fill = let i = ref 0 in
            fun x -> path.(!i) <- x-1; incr i
        in
        let ic = open_in  @@
            Printf.sprintf "C:/Users/Clement/Documents/prepa/tipe/ocaml-tsp/tsp/%s.opt.tour" tsp_name
        in
        let rec loop started = try (let s = String.trim @@ input_line ic in
            if started then (
                List.iter fill @@ List.map int_of_string @@ String.split_on_char ' ' s;
               loop true
            ) else loop ("TOUR_SECTION" = s)
            ) with _ -> ();
        in loop false;
        path

end;;
module Basetsp = struct
    let dists cities =
        let dist (c1x,c1y) (c2x,c2y) =
            int_of_float (0.5 +. sqrt ((c1x -. c2x)*.(c1x -. c2x) +. (c1y -. c2y)*. (c1y -. c2y)))
        in
        let city_count = Array.length cities in
        let adj_matrix = Array.init city_count (fun i -> Array.init city_count (fun j -> dist cities.(i) cities.(j)))
        in
        fun c1 c2 -> adj_matrix.(c1).(c2)
    let path_length eval path =
        let s = ref 0 in
        for i = 0 to Array.length path - 2 do
            s := !s + eval path.(i) path.(i+1)
        done;
        !s + eval path.(0) path.(Array.length path - 1)

    let best_path_length config eval =
        let path = Readertsp.open_path config in
        path_length eval path
end;;
module Showtsp = struct
    open Graphics
    type parameters = {mutable height: int; mutable width: int; mutable city_size: int}

    let params = {height=600; width=600; city_size=10}

    let coordToScreen (maxX, maxY) (x,y) =
           let a,b = float_of_int params.width *. 0.1 +. 0.8 *. float_of_int params.width *. x /. maxX,
            float_of_int params.height *. 0.1 +. 0.8 *. float_of_int params.height *. y /. maxY
        in int_of_float a, int_of_float b

    let show_cities cities =
        open_graph @@ Printf.sprintf "%dx%d" params.width params.height;
        clear_graph();
        set_line_width 1;
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities in
        Array.iteri (fun i (x,y) ->  set_color red; fill_circle x y params.city_size;set_text_size 20;set_color black;
                    moveto x y; draw_string @@ string_of_int i) @@ Array.map (coordToScreen (maxX, maxY)) cities

    let show_solution cities sol =
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities
        in
        let movetoT (x,y)= moveto x y
        in
        let coord = coordToScreen (maxX, maxY)
        in
        let lineto_city city = let x,y = coord cities.(city) in lineto x y
        in
        show_cities cities;
        set_line_width 3;
        set_color black;
        movetoT @@ coord cities.(sol.(0)) ;
        for k = 1 to Array.length sol - 1 do
            lineto_city sol.(k);
        done;
        lineto_city sol.(0)
        
    let show_solution_list cities sol =
        let maxX, maxY = Array.fold_left (fun (maxX, maxY) (x,y) -> (max maxX x), (max maxY y)) (0.,0.) cities
        in
        let movetoT (x,y)= moveto x y
        in
        let coord = coordToScreen (maxX, maxY)
        in
        let lineto_city city = let x,y = coord cities.(city) in lineto x y
        in
        show_cities cities;
        set_line_width 3;
        set_color black;
        let x :: xs = sol in 
            
        movetoT @@ coord cities.(x);
        List.iter lineto_city xs;
        lineto_city x
    let show_best_path config =
        let _, cities = Readertsp.open_tsp config in
        show_solution cities (Readertsp.open_path config)
    
end;;
module TwoOpt = struct
    let invertPath i j path =
        for k = 0 to (j - i)/2 - 1 do
             let t = path.(i+1+k) in
             path.(i+1+k) <- path.(j-k);
             path.(j-k) <- t;
         done
    let opt_best ?(debug = false) ?(maxi = -1) eval path =
        let bound = Array.length path in

        let rec loop k =
            let diff = ref 0 in
            let minI, minJ = ref 0, ref 0 in
                for i = 0 to bound - 4 do
                    for j = i+2 to bound - 1 - max 0 (1-i) do
                        let d = eval path.(i) path.(j) + eval path.(i+1) path.((j+1) mod bound)
                        - eval path.(i) path.(i+1) - eval path.(j) path.((j+1) mod bound)
                        in
                        if d < !diff then (
                            diff := d;
                            minI := i;
                            minJ := j
                        )
                    done
                done;
            if !diff < 0 then (
                invertPath !minI !minJ path;
                if debug then Printf.printf "\ninverted %d and %d" !minI !minJ;
                if k < maxi || maxi < 0 then loop (k+1)
            )
        in loop 1

    let opt_fast ?(debug = false) ?(maxi = -1) eval path =
        let bound = Array.length path in
        let rec rec_while i = (i < maxi || maxi < 0) &&
            not (loop1 0) && rec_while (i+1)
        and loop1 i = i >= bound - 4 || (loop2 i (i+2) && loop1 (i+1))
        and loop2 i j = j >= bound - max 0 (1-i)  || (
            let diff = eval path.(i) path.(j) + eval path.(i+1) path.((j+1) mod bound)
                                   - eval path.(i) path.(i+1) - eval path.(j) path.((j+1) mod bound)  in
            if diff < 0 then (
                invertPath i j path;
                if debug then Printf.printf "\ninverted %d and %d, diff : %d" i j diff;
                false
            ) else true
        ) && loop2 i (j+1)
        in
        let _ = rec_while 0 in ()

    type random_creation = Roulette | Random

    let weight_update eval last q = function
        | Random -> ()
        | Roulette -> RndQ.change_weights (fun _ x -> 1. /. float_of_int(eval x last)) q

    let random_path q eval mode city_count =
        Array.init city_count (
            fun _ -> let v = RndQ.take q in
                weight_update eval v q mode;
                v
        )

    let iter_two_opt n eval city_count rnd_mode =
        let arr = Array.init city_count (Fun.id) in
        let q = RndQ.simple_create city_count arr in
        let best_len = ref max_int in
        let best_path = Array.make city_count (-1) in
        for _ = 1 to n do
            let path = random_path q eval rnd_mode city_count in
            opt_fast eval path;
            let len = Basetsp.path_length eval path in
            if len < !best_len then (
                best_len := len;
                for i = 0 to city_count -1 do
                    best_path.(i) <- path.(i)
                done
            );
            RndQ.reset q

        done;
        best_path

end;;
module Primalg = struct
    let primalg eval city_count =
        let init_visited = IntSet.singleton 0 in
        let init_visit =
            let rec aux1 i acc =
            if i < city_count then aux1 (i + 1) (IntSet.add i acc) else acc
            in aux1 1 IntSet.empty
        in
        let rec aux to_visit visited score =
            if not @@ IntSet.is_empty to_visit then (
                let added = ref (-1) in
                let mini = ref max_int in
                IntSet.iter (fun c1 ->
                    IntSet.iter (fun c2 ->
                        let len = eval c1 c2 in
                        if len < !mini then (
                            mini := len;
                            added := c1
                        )) visited) to_visit;
                let new_to_visit = IntSet.remove !added to_visit
                in
                let new_visited = IntSet.add !added visited
                in
                aux new_to_visit new_visited (score +  !mini)
            ) else (
                score
            )
        in
        aux init_visit init_visited 0
end;;

