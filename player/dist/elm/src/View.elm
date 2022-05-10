module View exposing (view)

import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import Maybe exposing (withDefault)

import Model exposing (Model)
import Messages exposing (Msg(..))

view : Model -> Html Msg
view mm = case mm of 
  Nothing -> text "Couldnt find audio in perkeep"
  Just m ->
    div []
      [ div [] [ text m.player.activeTrack.name ]
      , button [ onClick Play ] [ text "Play" ]
      , button [ onClick Pause ] [ text "Pause" ]
      , button [ onClick Stop ] [ text "Stop" ]
      ]
