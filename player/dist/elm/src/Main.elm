module Main exposing (main)

import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)

import Model exposing (init)
import Messages exposing (Msg(..))
import Update exposing (update)
import View exposing (view)


main =
  Browser.element { 
    init = init,
    update = update,
    view = view,
    subscriptions = \_ -> Sub.none
  }
