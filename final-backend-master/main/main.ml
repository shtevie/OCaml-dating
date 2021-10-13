open Opium
open Src
open Lwt.Infix

let log_level = Some Logs.Info

let set_logger () =
  Logs.(
    set_reporter (Logs_fmt.reporter ());
    set_level log_level)

let _ =
  set_logger ();
  Lwt_main.run (Db.init () >>= Application.init);
  (* print_endline (Sys.getcwd ()); Lwt_main.run (Survey.load_questions
     "./src/questions.json"); *)
  Application.app |> App.run_command
