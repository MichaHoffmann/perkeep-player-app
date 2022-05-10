module Update exposing (update)

import Model exposing (Model, handlePlay, handlePause, handleStop)
import Messages exposing (Msg(..))

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Play  -> handlePlay model
    Pause -> handlePause model
    Stop  -> handleStop model

