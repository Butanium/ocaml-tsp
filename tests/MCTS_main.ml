let city_config = "att48"
let file_path = "tsp_instances" (* your path to the tsp directory, use the path from root if it doesn't work *)
let city_count, cities = Reader_tsp.open_tsp ~file_path city_config
let eval = Base_tsp.dists cities
let debug_tree = true 
let max_time = 1. 
let max_playout = 100000000
let path  = Monte_Carlo.proceed_mcts ~debug_tree ~city_config Monte_Carlo.Roulette Monte_Carlo.Min_spanning_tree city_count eval max_time max_playout


let () = print_endline "mcts path : "; Base_tsp.print_path path; Show_tsp.show_solution_and_wait cities path(* Show the computed solution *)

let () =
    let len = Base_tsp.path_length eval path in
    let best_len = Base_tsp.best_path_length city_config eval in
    Printf.printf "\n%% of error : %.2f %%\n\n" (100. *.float_of_int(len - best_len) /. float_of_int best_len);
    Base_tsp.print_best_path city_config