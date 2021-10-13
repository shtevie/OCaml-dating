open Src
open Lwt.Infix

let () =
  Lwt_main.run
    ( Db.init () >>= Db.reset >>= fun () ->
      Survey.load_questions "./src/questions.json" )
