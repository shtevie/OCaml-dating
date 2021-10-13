(** Test plan:

    The approach for our test plan was to ensure that each of our individual
    modules worked separately while also testing to make sure that they
    worked together. We tested automatically with Alcotest because it
    supports Lwt and is used by Opium, which we used to build our
    application. We also test manually by running through the user pipeline
    (i.e., testing out functionality on the app) to thoroughly try all the
    different features against user behavior. We tested many of the
    functions in the Application module through black box and glass box
    testing, depending on if we were testing endpoints or other functions,
    respectively. For the Database module, we used black box testing in
    order to ensure that the database worked as we intended. The tests for
    Survey, Matcher, Mserver, and Rating were a mix of black box and glass
    box testing. This was in order to have both test driven code and the
    ability to debug while coding. The Tables module was covered by other
    tests such as survey, match, chat, and rating since they used tables in
    the database. Because of the diversity of the tests we created,
    implementing black box, glass box, and manual testing, we believe that
    this exhaustively covers all the different ways that our application's
    features are used, and passing these tests will ensure the system is
    fully functional. *)

open Alcotest
open Lwt.Infix
open Lwt.Syntax
open Opium_testing
open Src
open Tables
module Request = Opium.Request
module Response = Opium.Response
module Cookie = Opium.Cookie
module Body = Opium.Body
open Matcher

let test_case n f = Alcotest_lwt.test_case n `Quick (fun _switch () -> f ())

let handle_request = handle_request Application.app

let pp_user ppf (x : user) = Fmt.pf ppf "User: %s" x.name

let pp_session ppf (x : session) =
  Fmt.pf ppf "sessid: %s, user: %d" x.sessid x.user_id

let user_testable = Alcotest.testable pp_user ( = )

let session_testable = Alcotest.testable pp_session ( = )

let obj_testable (a : 'a testable) : 'a obj testable =
  let eq (x : 'a obj) (y : 'a obj) = equal a x.o y.o in
  testable (fun fmt x -> Format.fprintf fmt "%a" (pp a) x.o) eq

let json_testable =
  Alcotest.testable Yojson.Safe.pretty_print Yojson.Safe.equal

(* TODO: reset database after each test case *)

let user1 : user =
  { name = "name1"; username = "username1"; password = "Test1234!" }

let user2 : user = { name = "name2"; username = "username2"; password = "" }

let check_body_json ?(msg = "bodies equal") json body =
  let+ b = Body.to_string body in
  check json_testable msg
    (json |> Yojson.Safe.from_string)
    (b |> Yojson.Safe.from_string)

let check_message ?(msg = "messages equal") exp (r : Response.t) =
  check_status `OK r.status;
  let+ b = Body.to_string r.body in
  check json_testable msg
    (`Assoc [ ("message", `String exp) ])
    (b |> Yojson.Safe.from_string)

let check_error
    ?(status = `Bad_request)
    ?(msg = "error messages equal")
    exp
    (r : Response.t) =
  check_status status r.status;
  let+ b = Body.to_string r.body in
  check json_testable msg
    (`Assoc [ ("error", `String exp) ])
    (b |> Yojson.Safe.from_string)

let cookie_testable = Alcotest.testable Cookie.pp ( = )

let pp_question ppf (x : question) =
  Fmt.pf ppf "text: %s, %d possible choices" x.text (List.length x.choices)

let question_testable = Alcotest.testable pp_question ( = )

let pp_user_rating ppf (x : user_rating) =
  Fmt.pf ppf "user: %d, %d total rating with %d ratings" x.user_id
    x.total_ratings x.count

let user_rating_testable = Alcotest.testable pp_user_rating ( = )

let pp_rating ppf (x : rating) =
  Fmt.pf ppf "{%d -> %d, waiting: %b, value: %s, chat_id: %d" x.from_id
    x.to_id x.waiting
    (match x.value with None -> "none" | Some v -> string_of_int v)
    x.chat_id

let rating_testable = Alcotest.testable pp_rating ( = )

let check_set_auth_headers
    ?(msg = "request has auth headers for user")
    user
    (r : Response.t) =
  let h = Response.header "Set-Cookie" r |> Option.get in
  let c = Cookie.of_set_cookie_header ("Set-Cookie", h) |> Option.get in
  let+ u = Auth.user_of_sessid (snd c.value) in
  let u = Option.get u in
  check user_testable msg user u.o

let sample_req =
  Request.of_json
    ~body:
      (`Assoc
        [
          ("username", `String "username1");
          ("name", `String "name1");
          ("password", `String "Test1234!");
        ])
    "/users/create" `POST

let post_users_create =
  ( "POST /users/create",
    [
      test_case "returns OK" (fun () ->
          Db.reset () >>= fun () ->
          let* res = handle_request sample_req in
          check_message "user created" res >>= fun () ->
          let* u = Db.find_one_s users "username" "username1" in
          let u = Option.get u in
          check user_testable "users are the same" user1 u.o;
          check_set_auth_headers user1 res);
      test_case "username taken and must be unique" (fun () ->
          Db.reset () >>= fun () ->
          let req2 =
            Request.of_json
              ~body:
                (`Assoc
                  [
                    ("username", `String "username1");
                    ("name", `String "name2");
                    ("password", `String "Test1234!");
                  ])
              "/users/create" `POST
          in
          let* _ = handle_request sample_req in
          let* _ = handle_request req2 in
          let+ u = Db.find_one_s users "username" "username1" in
          let n =
            match u with
            | None -> failwith "impossible"
            | Some u -> u.o.name
          in
          check Alcotest.bool "make sure the name not overridden" true
            (n = "name1"));
      test_case "password must contain the right variety of characters"
        (fun () ->
          Db.reset () >>= fun () ->
          let bad_req1 =
            Request.of_json
              ~body:
                (`Assoc
                  [
                    ("username", `String "username1");
                    ("name", `String "name1");
                    ("password", `String "Test1234");
                  ])
              "/users/create" `POST
          in
          let bad_req2 =
            Request.of_json
              ~body:
                (`Assoc
                  [
                    ("username", `String "username1");
                    ("name", `String "name1");
                    ("password", `String "test1234!");
                  ])
              "/users/create" `POST
          in
          let* res1 = handle_request bad_req1 in
          let* res2 = handle_request bad_req2 in

          check_error "invalid password" res1 >>= fun () ->
          check_error "invalid password" res2);
      test_case "password must be of sufficient length" (fun () ->
          Db.reset () >>= fun () ->
          let bad_req =
            Request.of_json
              ~body:
                (`Assoc
                  [
                    ("username", `String "username1");
                    ("name", `String "name1");
                    ("password", `String "");
                  ])
              "/users/create" `POST
          in
          let* res = handle_request bad_req in
          check_error "invalid password" res);
    ] )

let reset_and_create_users () =
  Db.reset () >>= fun () ->
  Db.create users user1 >>= fun _ -> Db.create users user2

let post_signin_request username password =
  let l = [] in
  let l =
    if username <> None then
      ("username", `String (Option.get username)) :: l
    else l
  in
  let l =
    if password <> None then
      ("password", `String (Option.get password)) :: l
    else l
  in
  Request.of_json ~body:(`Assoc l) "/users/signin" `POST

let post_signin_users =
  ( "POST /users/signin",
    [
      test_case "sucessful" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let req = post_signin_request (Some "username2") (Some "") in
          let* res = handle_request req in
          check_message "signin success" res >>= fun () ->
          check_set_auth_headers user2 res >>= fun () ->
          let+ cnt = Db.cnt sessions in
          check Alcotest.int "1 session should be created" 1 cnt);
      test_case "no username" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let req = post_signin_request None (Some "") in
          let* res = handle_request req in
          check_status `Bad_request res.status;
          let+ cnt = Db.cnt sessions in
          check Alcotest.int "no sessions should be created" 0 cnt);
      test_case "no password" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let req = post_signin_request (Some "username1") None in
          let+ res = handle_request req in
          check_status `Bad_request res.status);
      test_case "bad password" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let req = post_signin_request (Some "username1") (Some "b") in
          let* res = handle_request req in
          check_error "incorrect username or password" res >>= fun () ->
          let+ cnt = Db.cnt sessions in
          check Alcotest.int "no sessions should be created" 0 cnt);
    ] )

let add_sess_cookie sess = Request.add_cookie ("sessid", sess.o.sessid)

let check_unauthorized (res : Response.t) =
  check_error ~status:`Unauthorized "not logged in or invalid session" res

let get_user_tests =
  ( "GET /user",
    [
      test_case "authorized" (fun () ->
          let* _ = Db.create users user1 in
          let* u = Db.create users user2 in
          let* s = Auth.new_session u.id in
          let req = Request.get "/user" |> add_sess_cookie s in
          let* res = handle_request req in
          check_status `OK res.status;
          check_body_json
            {|{"username": "username2", "name": "name2", "rating": 0.0}|}
            res.body);
      test_case "unauthorized" (fun () ->
          let req = Request.get "/user" in
          let* res = handle_request req in
          check_unauthorized res);
    ] )

let database_tests =
  ( "database",
    [
      test_case "create one user" (fun () ->
          Db.reset () >>= fun () ->
          let+ obj = Db.create users user1 in
          check user_testable "" user1 obj.o);
      test_case "create two users" (fun () ->
          Db.reset () >>= fun () ->
          let+ obj1 = Db.create users user1
          and* obj2 = Db.create users user2 in
          (* check equals *)
          check user_testable "" user1 obj1.o;
          check user_testable "" user2 obj2.o);
      test_case "all of two users" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let+ l = Db.all users in
          let l = List.map (fun x -> x.o) l |> List.sort_uniq compare in
          let exp = [ user1; user2 ] |> List.sort_uniq compare in
          check
            (Alcotest.list user_testable)
            "list should contain user1 and user2" exp l);
      test_case "all of no users" (fun () ->
          Db.reset () >>= fun () ->
          let+ l = Db.all users in
          check Alcotest.bool "list should be empty" true (l = []));
      test_case "find username given two users" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let+ uo = Db.find_one_s users "username" "username1" in
          let u = Option.get uo in
          check user_testable "" user1 u.o);
      test_case "username can't be found" (fun () ->
          reset_and_create_users () >>= fun _ ->
          let+ uo = Db.find_one_s users "username" "username" in
          check Alcotest.bool "uo = None" true (uo = None));
      test_case "create one session" (fun () ->
          Db.reset () >>= fun () ->
          let s : session = { sessid = ""; user_id = 0 } in
          let* so = Db.create sessions s in
          let+ o = Db.get sessions so.id in
          check session_testable
            "session from database is same as one used to create it" s o.o);
      test_case "create one question" (fun () ->
          Db.reset () >>= fun () ->
          let q : question =
            {
              text = "how are you?";
              choices = [ { text = "good" }; { text = "bad" } ];
            }
          in
          let* qo = Db.create questions q in
          let+ o = Db.get questions qo.id in
          check question_testable
            "question from database is same as one used to create it" q o.o);
      test_case "delete one user cnt" (fun () ->
          Db.reset () >>= fun () ->
          let* obj = Db.create users user1 in
          Db.delete users obj.id >>= fun () ->
          let* cnt = Db.cnt users in
          check Alcotest.int
            "there are no more entries in the db after deleting the only \
             one"
            0 cnt;
          let+ o = Db.get_opt sessions obj.id in
          check Alcotest.bool "o = None" true (o = None));
    ] )

let test_auth_handler =
  Auth.require_auth (fun user _ ->
      Response.of_plain_text (Format.asprintf "%d" user.id) |> Lwt.return)

let auth_tests =
  ( "auth",
    [
      test_case "new session" (fun () ->
          Db.reset () >>= fun () ->
          let* obj = Db.create users user1 and* _ = Db.create users user2 in
          let* s = Auth.new_session obj.id in
          (* check that session has correct user_id *)
          check Alcotest.int "session user_id is id of user1" s.o.user_id
            obj.id;
          (* check that session was created in the database *)
          let+ so = Db.get sessions s.id in
          check session_testable "returned session is same as in database"
            s.o so.o);
      test_case "sessid is unique" (fun () ->
          Db.reset () >>= fun () ->
          let* obj = Db.create users user1 and* _ = Db.create users user2 in
          let trials = 25 in
          let* _ =
            Lwt_list.fold_left_s
              (fun acc () ->
                let+ o = Auth.new_session obj.id in
                check Alcotest.bool "sessid has not already been generated"
                  true
                  (List.find_opt (( = ) o.o.sessid) acc |> Option.is_none);
                o.o.sessid :: acc)
              []
              (List.init trials (fun _ -> ()))
          in
          Lwt.return_unit);
      test_case "user of invalid sessid" (fun () ->
          Db.reset () >>= fun () ->
          let+ a = Auth.user_of_sessid "aaaaaa" in
          check Alcotest.bool "result is None" true (Option.is_none a));
      test_case "user of valid sessid" (fun () ->
          Db.reset () >>= fun () ->
          let* u = Db.create users user1 in
          let* s = Auth.new_session u.id in
          let+ a = Auth.user_of_sessid s.o.sessid in
          let a = Option.get a in
          check user_testable "result is user1" user1 a.o);
      test_case "user of authorized request" (fun () ->
          Db.reset () >>= fun () ->
          let* u = Db.create users user1 in
          let* _ = Db.create users user2 in
          let* s = Auth.new_session u.id in
          let r =
            Request.post "" |> Request.add_cookie ("sessid", s.o.sessid)
          in
          let+ a = Auth.user_of_request r in
          let a = Option.get a in
          print_endline a.o.username;
          check user_testable "result should be user1" user1 a.o);
      test_case "user of request with no sessid" (fun () ->
          Db.reset () >>= fun () ->
          let* u = Db.create users user1 in
          let* _ = Db.create users user2 in
          let* _ = Auth.new_session u.id in
          let r = Request.post "" in
          let+ a = Auth.user_of_request r in
          check Alcotest.bool "result should be None" true (a = None));
      test_case "user of request with invalid sessid" (fun () ->
          Db.reset () >>= fun () ->
          let* u = Db.create users user1 in
          let* _ = Db.create users user2 in
          let* _ = Auth.new_session u.id in
          let r =
            Request.post "" |> Request.add_cookie ("sessid", "aaaa")
          in
          let+ a = Auth.user_of_request r in
          check Alcotest.bool "result should be None" true (a = None));
      test_case "add auth header" (fun () ->
          Db.reset () >>= fun () ->
          let* u = Db.create users user1 in
          let+ s = Auth.new_session u.id in
          let r = Response.of_plain_text "" |> Auth.add_auth_headers s.o in
          let cookie =
            Opium.Cookie.make ("sessid", s.o.sessid)
              ~scope:(Uri.of_string "/")
            |> Opium.Cookie.to_set_cookie_header
          in
          let exp =
            Response.of_plain_text "" |> Response.add_header cookie
          in
          check_response r exp);
      test_case "login" (fun () ->
          Db.reset () >>= fun () ->
          let* u = Db.create users user1 in
          let+ s, r = Response.of_plain_text "" |> Auth.login u.id in
          let cookie =
            Opium.Cookie.make ("sessid", s.o.sessid)
              ~scope:(Uri.of_string "/")
            |> Opium.Cookie.to_set_cookie_header
          in
          let exp =
            Response.of_plain_text "" |> Response.add_header cookie
          in
          check_response r exp);
      test_case "authenticated request to test_auth_handler" (fun () ->
          Db.reset () >>= fun () ->
          let* _ = Db.create users user1 in
          let* u = Db.create users user2 in
          let* s = Auth.new_session u.id in
          let req =
            Request.get "" |> Request.add_cookie ("sessid", s.o.sessid)
          in
          let+ res = test_auth_handler req in
          let exp = Response.of_plain_text (Format.asprintf "%d" u.id) in
          check_response exp res);
      test_case "unauthorized request to test_auth_handler" (fun () ->
          let req =
            Request.get "" |> Request.add_cookie ("sessid", "aaa")
          in
          let* res = test_auth_handler req in
          check_unauthorized res);
    ] )

let survey_tests =
  ( "survey",
    [
      test_case "load test questions" (fun () ->
          Db.reset () >>= fun () ->
          Survey.load_questions "test_qs1.json" >>= fun () ->
          let* cnt = Db.cnt questions in
          check Alcotest.int "8 questions in test_qs1 are created" 8 cnt;
          let check_q_present text =
            let+ o = Db.find_one_s questions "text" text in
            check Alcotest.bool
              ("question " ^ text ^ " is present")
              true (Option.is_some o)
          in
          let* o = Db.find_one_s questions "text" "B" in
          let o = Option.get o in
          check question_testable ""
            {
              text = "B";
              choices = [ { text = "a" }; { text = "b" }; { text = "c" } ];
            }
            o.o;
          Lwt_list.iter_p check_q_present [ "A"; "B"; "C"; "D" ]);
      test_case "generating new survey" (fun () ->
          Db.reset () >>= fun () ->
          Survey.load_questions "test_qs1.json" >>= fun () ->
          let+ surv = Survey.new_survey () in
          check Alcotest.int "4 questions are generated for the survey" 4
            (List.length surv.questions));
      test_case "survey should have distinct questions" (fun () ->
          Db.reset () >>= fun () ->
          Survey.load_questions "test_qs1.json" >>= fun () ->
          let+ surv = Survey.new_survey () in
          let rec iterate_check = function
            | h :: t ->
                let filtered =
                  List.filter (fun x -> x = h) surv.questions
                in
                print_int (List.length filtered);
                if List.length filtered > 1 then false else iterate_check t
            | [] -> true
          in
          check Alcotest.bool "no questions are the same in a survey" true
            (iterate_check surv.questions));
    ] )

let user1 : user = { name = "name1"; username = "username1"; password = "" }

let user2 : user = { name = "name2"; username = "username2"; password = "" }

let user3 : user = { name = "name3"; username = "username3"; password = "" }

let q1 : question =
  { text = "text1"; choices = [ { text = "a" }; { text = "b" } ] }

let user1_response1 : response =
  { username = "username1"; question_text = "text1"; choice_id = 1 }

let user2_response1 : response =
  { username = "username2"; question_text = "text1"; choice_id = 1 }

let user3_response1 : response =
  { username = "username3"; question_text = "text3"; choice_id = 2 }

let populate_users_and_responses () =
  Db.reset () >>= fun () ->
  let* u1 = Db.create users user1 in
  let* u2 = Db.create users user2 in
  let* u3 = Db.create users user3 in
  let active_user1 = { user_id = u1.id } in
  let active_user2 = { user_id = u2.id } in
  let active_user3 = { user_id = u3.id } in
  Db.create questions q1 >>= fun _ ->
  let* au1 = Db.create active_users active_user1 in
  let* au2 = Db.create active_users active_user2 in
  let* au3 = Db.create active_users active_user3 in
  Db.create responses user1_response1 >>= fun _ ->
  Db.create responses user2_response1 >>= fun _ ->
  Db.create responses user3_response1 >>= fun _ ->
  Lwt.return (u1, u2, u3, au1, au2, au3)

let match_tests =
  ( "find correct match",
    [
      test_case "username1 should match with username2" (fun () ->
          let* u1, u2, _, _, _, _ = populate_users_and_responses () in
          let+ m = most_compatible u1.id in
          match m with
          | None -> failwith "not possible"
          | Some id -> check Alcotest.bool "check ids" true (id = u2.id));
      test_case
        "match summary info should reflect all the details of the match"
        (fun () ->
          let* u1, _, _, _, _, _ = populate_users_and_responses () in
          let* m = match_summary u1.id in
          match m with
          | None -> failwith "not possible"
          | Some ms ->
              let* expected_questions1 =
                Db.find_s questions "text" user1_response1.question_text
              in
              let+ expected_questions2 =
                Db.find_s questions "text" user2_response1.question_text
              in
              check Alcotest.bool "check match_summary object" true
                (ms.o.user_one_responses = [ user1_response1 ]
                && ms.o.user_two_responses = [ user2_response1 ]
                && ms.o.user_one_questions
                   = [ (List.hd expected_questions1).o ]
                && ms.o.user_two_questions
                   = [ (List.hd expected_questions2).o ]));
      test_case
        "match summary detail should reflect all the details of the match"
        (fun () ->
          let* u1, _, _, _, _, _ = populate_users_and_responses () in
          let* m = match_summary u1.id in
          match m with
          | None -> failwith "not possible"
          | Some ms ->
              let+ match_details_string = match_details ms.o in
              check Alcotest.string "check match_summary object"
                match_details_string
                "This wonderful match was made between username1 and \
                 username2.\n\n\
                 The questions you both answered were:\n\n\
                 text1\n\n\
                 The questions you gave the same responses to were:\n\n\
                 text1\n\n\
                 ...to which you both responded with:\n\n\
                 b\n");
      test_case "match state is Inactive if user is not active" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let+ st = match_state u1.id in
          check Alcotest.bool "check for Inactive" true (Inactive = st));
      test_case "match state is Matching if user is active" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let active_user1 = { user_id = u1.id } in
          Db.create active_users active_user1 >>= fun _ ->
          let+ st = match_state u1.id in
          check Alcotest.bool "check for Matching" true (Matching = st));
      test_case "match state is Matched if user is active" (fun () ->
          let* u1, _, _, au1, _, _ = populate_users_and_responses () in
          let* m = match_summary u1.id in
          Db.delete active_users au1.id >>= fun () ->
          match m with
          | Some ms -> (
              let* st = match_state u1.id in
              match st with
              | Matching -> failwith "cannot be Matching"
              | Inactive -> failwith "cannot be Inactive"
              | Matched c ->
                  let+ chat_obj = Db.get chats ms.o.chat_id in
                  check Alcotest.bool "check for Matching" true
                    (c = chat_obj))
          | None -> failwith "cannot be None");
    ] )

(* let* res = handle_request req in check_message "user created" res >>= fun
   () -> let* u = Db.find_one users "username" "username1" in let u =
   Option.get u in check user_testable "" user1 u.o; check_set_auth_headers
   user1 res); ] ) *)

let user_id_ref = ref 0

let logged_in_req u r =
  let+ s = Auth.new_session u.id in
  r |> Request.add_cookie ("sessid", s.o.sessid)

let test_rating from_id to_id =
  { waiting = true; from_id; to_id; chat_id = 0; value = None }

let post_rating_tests =
  ( "POST /rating",
    [
      test_case "first rating" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let* u2 = Db.create users user2 in
          let rating = test_rating u1.id u2.id in
          let* rating_obj = Db.create ratings rating in
          let uid = u2.id in
          user_id_ref := uid;
          let req =
            Request.of_json
              ~body:(`Assoc [ ("rating", `Int 5) ])
              "/rating" `POST
          in
          let* req = logged_in_req u1 req in
          let* res = handle_request req in
          check_status `OK res.status;
          let* u = Db.find_one_i user_ratings "user_id" uid in
          let u = Option.get u in
          check user_rating_testable "user2 has one rating of 5"
            { user_id = u2.id; total_ratings = 5; count = 1 }
            u.o;
          let+ rating_obj = Db.get ratings rating_obj.id in
          check rating_testable "rating has updated fields"
            { rating with value = Some 5; waiting = false }
            rating_obj.o);
      test_case "with existing user_rating" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let* u2 = Db.create users user2 in
          let* user_rating =
            Db.create user_ratings
              { user_id = u2.id; total_ratings = 5; count = 1 }
          in
          let rating = test_rating u1.id u2.id in
          let* _ = Db.create ratings rating in
          let req =
            Request.of_json
              ~body:(`Assoc [ ("rating", `Int 4) ])
              "/rating" `POST
          in
          let* req = logged_in_req u1 req in
          let* res = handle_request req in
          check_status `OK res.status;
          let* u = Db.get user_ratings user_rating.id in
          check user_rating_testable "user2 has two ratings of 9"
            { user_id = u2.id; total_ratings = 9; count = 2 }
            u.o;
          let+ avg = Rating.average_rating u2.id in
          check (Alcotest.float 0.25) "avg is now 4.5" 4.5 avg);
      test_case "without rating" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let* u2 = Db.create users user2 in
          let* user_rating =
            Db.create user_ratings
              { user_id = u2.id; total_ratings = 5; count = 1 }
          in
          let req =
            Request.of_json
              ~body:(`Assoc [ ("rating", `Int 4) ])
              "/rating" `POST
          in
          let* req = logged_in_req u1 req in
          let* res = handle_request req in
          check_status `Unauthorized res.status;
          let+ u = Db.get user_ratings user_rating.id in
          check user_rating_testable "user2 has two ratings of 9"
            { user_id = u2.id; total_ratings = 5; count = 1 }
            u.o);
    ] )

let rating_tests = ("rating", [])

let pp_msg_body ppf = function
  | Mserver.Auth sessid -> Fmt.pf ppf "auth: %s" sessid
  | Mserver.Data d -> Fmt.pf ppf "data: %s" (Yojson.Safe.to_string d)

let msg_body_testable = Alcotest.testable pp_msg_body ( = )

let hex_to_bytes h = Hex.to_bytes (`Hex h)

let parse_test name ins exp =
  test_case name (fun _ ->
      let ic =
        Lwt_io.of_bytes ~mode:Lwt_io.input
          (hex_to_bytes ins |> Lwt_bytes.of_bytes)
      in
      let+ m = Mserver.parse_msg ic in
      check msg_body_testable "parsed message is expected" exp m)

let parse_test_exc name ins exp =
  test_case name (fun _ ->
      let ic =
        Lwt_io.of_bytes ~mode:Lwt_io.input
          (hex_to_bytes ins |> Lwt_bytes.of_bytes)
      in
      Lwt.try_bind
        (fun () -> Mserver.parse_msg ic)
        (fun _ -> fail "message parsed")
        (fun exn ->
          check_raises "expected exception raised" exp (fun () -> raise exn)
          |> Lwt.return))

let mserver_tests =
  ( "mserver",
    [
      parse_test "auth"
        "0074657152633152746d782b616b313454446c577a4b574652324d354a486d767a"
        (Auth "teqRc1Rtmx+ak14TDlWzKWFR2M5JHmvz");
      parse_test "data" "01000000107b226d657373616765223a226869227d"
        (Data (`Assoc [ ("message", `String "hi") ]));
      parse_test "multiple messages"
        "0074657152633152746d782b616b313454446c577a4b574652324d354a486d767a01000000107b226d657373616765223a226869227d"
        (Auth "teqRc1Rtmx+ak14TDlWzKWFR2M5JHmvz");
      parse_test_exc "bad auth"
        "0074657152633152746d782b616b313454446c577a4b574652324d354a486d76"
        End_of_file;
      parse_test_exc "bad packet type" "03ffffffffffff"
        Mserver.Invalid_message_format;
      test_case "successful handshake" (fun _ ->
          let+ res =
            Mserver.handshake (fun () ->
                Some (Mserver.Auth "test") |> Lwt.return)
          in
          check
            (Alcotest.option Alcotest.string)
            "result is Some test" (Some "test") res);
      test_case "handshake with data" (fun _ ->
          let+ res =
            Mserver.handshake (fun () ->
                Some (Mserver.Data `Null) |> Lwt.return)
          in
          check (Alcotest.option Alcotest.string) "result is None" None res);
      test_case "handshake with data" (fun _ ->
          let+ res = Mserver.handshake (fun () -> None |> Lwt.return) in
          check (Alcotest.option Alcotest.string) "result is None" None res);
    ] )

let pp_chat ppf (x : chat) =
  Fmt.pf ppf "active: %b, user one %i, user two %i" x.active x.user_one
    x.user_two

let chat_testable = Alcotest.testable pp_chat ( = )

let pp_chatlog ppf (x : chatlog) =
  Fmt.pf ppf "chat id %i and num of messages %i" x.chat_id
    (List.length x.messages)

let chatlog_testable = Alcotest.testable pp_chatlog ( = )

let chat_tests =
  ( "chat",
    [
      test_case "get_chats" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let* u2 = Db.create users user2 in
          let chat =
            { active = true; user_one = u1.id; user_two = u2.id }
          in
          let* chat_obj = Db.create chats chat in
          let c1 =
            `Assoc
              [
                ( "text",
                  chat_obj.o.user_two |> string_of_int
                  |> Yojson.Safe.from_string );
              ]
          in
          let c2 =
            `Assoc
              [
                ( "text",
                  chat_obj.o.user_one |> string_of_int
                  |> Yojson.Safe.from_string );
              ]
          in
          let matched_chats = [ c1; c2 ] in
          let req =
            Request.of_json
              ~body:(`Assoc [ ("chats", `List matched_chats) ])
              "/user/chats" `GET
          in
          let* req = logged_in_req u1 req in
          let* res = handle_request req in
          check_status `OK res.status;
          let+ c = Db.find_i chats "user_one" u1.id in
          check chat_testable "true, user1, user2"
            { active = true; user_one = u1.id; user_two = u2.id }
            (List.hd c).o);
      test_case "chatlogs" (fun () ->
          Db.reset () >>= fun () ->
          let* u1 = Db.create users user1 in
          let* u2 = Db.create users user2 in
          let chat =
            { active = true; user_one = u1.id; user_two = u2.id }
          in
          let* chat_obj = Db.create chats chat in
          let chatlog = { chat_id = chat_obj.id; messages = [] } in
          let* _ = Db.create chatlogs chatlog in
          let* () = Application.update_chatlog chat_obj.id u1.id "hello" in
          let messages = [ { user_id = u1.id; content = "hello" } ] in
          let+ chatlog_obj = Db.find_one_i chatlogs "chat_id" chat_obj.id in
          check chatlog_testable "chatlog test"
            { chat_id = chat_obj.id; messages }
            (Option.get chatlog_obj).o);
    ] )

let suite =
  [
    post_users_create;
    database_tests;
    get_user_tests;
    post_signin_users;
    auth_tests;
    survey_tests;
    mserver_tests;
    match_tests;
    rating_tests;
    post_rating_tests;
    chat_tests;
  ]

let run = Db.init () >>= fun () -> Alcotest_lwt.run "User" suite

let () =
  Printexc.record_backtrace true;
  Lwt_main.run run
