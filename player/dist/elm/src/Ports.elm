port module Ports exposing (init, play, pause, stop)

import Array exposing (Array)

port init : String -> Cmd msg

port play : () -> Cmd msg

port pause : () -> Cmd msg

port stop : () -> Cmd msg
