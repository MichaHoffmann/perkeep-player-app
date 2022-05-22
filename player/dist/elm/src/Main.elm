module Main exposing (main)

import Browser
import Html
    exposing
        ( Html
        , button
        , div
        , input
        , strong
        , table
        , tbody
        , td
        , text
        , th
        , thead
        , tr
        )
import Html.Attributes exposing (type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import List.Nonempty as NE
import Perkeep exposing (getTracks, urlFromBlobRef)
import Player exposing (Player, PlayerState(..), Playlist, Track, toPlaylists)
import Ports
import Process
import Task
import Time



{-
   TODO:
   * UX for multiple playlists
   * Search
   * Any CSS
-}


type Msg
    = GotNewTracks (Result Http.Error (NE.Nonempty Track))
      -- Timing Events
    | RefreshSeekState
      -- Html Events
    | HtmlPressedPlayPause
    | HtmlPressedStop
    | HtmlPressedNext
    | HtmlPressedPlaylistIdx Int
    | HtmlVolumeRange Float
    | HtmlSeekTo Float
      -- Js Events
    | JsNotifyPlayerOnInitialized
    | JsNotifyPlayerOnLoad Float
    | JsNotifyPlayerOnLoadError String
    | JsNotifyPlayerOnPlay
    | JsNotifyPlayerOnPlayError String
    | JsNotifyPlayerOnPause
    | JsNotifyPlayerOnStop
    | JsNotifyPlayerOnEnd
    | JsNotifyPlayerOnVolume Float
    | JsNotifyPlayerSeekState Float
    | JsNotifyBadMessage String


type Model
    = InitializingModel Int
    | InitializedModel Player (NE.Nonempty Playlist)


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : ( Model, Cmd Msg )
init =
    ( InitializingModel 0, Task.attempt GotNewTracks getTracks )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        InitializingModel attempts ->
            updateInitializingModel msg attempts

        InitializedModel player playlists ->
            updateInitializedModel msg player playlists


updateInitializingModel : Msg -> Int -> ( Model, Cmd Msg )
updateInitializingModel msg attempts =
    let
        backoffMs =
            5000.0
    in
    case msg of
        GotNewTracks result ->
            case result of
                Ok tracks ->
                    let
                        playlists =
                            toPlaylists tracks

                        player =
                            { state = Stopped
                            , playlist = NE.head playlists
                            , idx = 0
                            , volume = 10
                            , duration = 0
                            , at = 0
                            }
                    in
                    ( InitializedModel player playlists
                    , Cmd.none
                    )

                Err _ ->
                    ( InitializingModel (attempts + 1)
                    , Task.attempt GotNewTracks
                        (Process.sleep backoffMs |> Task.andThen (\_ -> getTracks))
                    )

        _ ->
            ( InitializingModel attempts, Cmd.none )


updateInitializedModel : Msg -> Player -> NE.Nonempty Playlist -> ( Model, Cmd Msg )
updateInitializedModel msg player playlists =
    let
        playAtIdx =
            \idx ->
                let
                    track =
                        NE.get idx player.playlist.tracks

                    p =
                        { player | idx = idx, state = Loading }
                in
                ( InitializedModel p playlists
                , Ports.sendMsg (Ports.ToJsInit (urlFromBlobRef track.blobref))
                )
    in
    case ( msg, player.state ) of
        -- Js Events, should control player state
        ( JsNotifyPlayerOnInitialized, _ ) ->
            let
                p =
                    { player | state = Loading, duration = 0, at = 0 }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnLoad dur, _ ) ->
            let
                p =
                    { player | state = Loading, duration = dur }
            in
            ( InitializedModel p playlists
            , Ports.sendMsg Ports.ToJsPlay
            )

        ( JsNotifyPlayerOnLoadError err, _ ) ->
            let
                p =
                    { player | state = NotLoadedError err }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnPlay, _ ) ->
            let
                p =
                    { player | state = Playing }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnPlayError err, _ ) ->
            let
                p =
                    { player | state = PlayingError err }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnPause, _ ) ->
            let
                p =
                    { player | state = Paused }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnStop, _ ) ->
            let
                p =
                    { player | state = Stopped, at = 0 }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnVolume vol, _ ) ->
            let
                p =
                    { player | volume = vol }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerSeekState seek, _ ) ->
            let
                p =
                    { player | at = seek }
            in
            ( InitializedModel p playlists
            , Cmd.none
            )

        ( JsNotifyPlayerOnEnd, _ ) ->
            playAtIdx (player.idx + 1)

        -- Html Events, should call into Js functions
        ( HtmlPressedPlaylistIdx idx, _ ) ->
            playAtIdx idx

        ( HtmlVolumeRange vol, _ ) ->
            ( InitializedModel player playlists
            , Ports.sendMsg (Ports.ToJsVolume vol)
            )

        ( HtmlSeekTo seek, _ ) ->
            ( InitializedModel player playlists
            , Ports.sendMsg (Ports.ToJsSeekTo seek)
            )

        ( HtmlPressedPlayPause, Stopped ) ->
            playAtIdx player.idx

        ( HtmlPressedPlayPause, Paused ) ->
            ( InitializedModel player playlists
            , Ports.sendMsg Ports.ToJsPlay
            )

        ( HtmlPressedPlayPause, Playing ) ->
            ( InitializedModel player playlists
            , Ports.sendMsg Ports.ToJsPause
            )

        ( HtmlPressedStop, _ ) ->
            ( InitializedModel player playlists
            , Ports.sendMsg Ports.ToJsStop
            )

        ( HtmlPressedNext, _ ) ->
            playAtIdx (player.idx + 1)

        -- Timing events
        ( RefreshSeekState, Playing ) ->
            ( InitializedModel player playlists
            , Ports.sendMsg Ports.ToJsGetSeekState
            )

        -- TODO: transitions from error states
        _ ->
            ( InitializedModel player playlists, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.receiveMsg
            (\msg ->
                case msg of
                    Ports.FromJsOnInitialized ->
                        JsNotifyPlayerOnInitialized

                    Ports.FromJsOnLoad dur ->
                        JsNotifyPlayerOnLoad dur

                    Ports.FromJsOnLoadError err ->
                        JsNotifyPlayerOnLoadError err

                    Ports.FromJsOnPlay ->
                        JsNotifyPlayerOnPlay

                    Ports.FromJsOnPlayError err ->
                        JsNotifyPlayerOnPlayError err

                    Ports.FromJsOnPause ->
                        JsNotifyPlayerOnPause

                    Ports.FromJsOnStop ->
                        JsNotifyPlayerOnStop

                    Ports.FromJsOnEnd ->
                        JsNotifyPlayerOnEnd

                    Ports.FromJsOnVolume vol ->
                        JsNotifyPlayerOnVolume vol

                    Ports.FromJsSeekState seek ->
                        JsNotifyPlayerSeekState seek

                    Ports.FromJsBadMessage err ->
                        JsNotifyBadMessage err
            )
        , Time.every 1000.0 (\_ -> RefreshSeekState)
        ]


view : Model -> Html Msg
view m =
    case m of
        InitializingModel attempts ->
            viewInitializingModel attempts

        InitializedModel player playlists ->
            viewInitializedModel player playlists


viewInitializingModel : Int -> Html Msg
viewInitializingModel attempts =
    text ("Loading Tracks..." ++ "(" ++ String.fromInt attempts ++ " attempts)")


viewInitializedModel : Player -> NE.Nonempty Playlist -> Html Msg
viewInitializedModel player _ =
    div []
        [ div [] [ text (NE.get player.idx player.playlist.tracks).name ]
        , div []
            [ viewPlayerState player.state
            , input
                [ type_ "range"
                , value (String.fromFloat player.at)
                , Html.Attributes.max (String.fromFloat player.duration)
                , onInput (HtmlSeekTo << Maybe.withDefault player.at << String.toFloat)
                ]
                []
            ]
        , button [ onClick HtmlPressedPlayPause ] [ text "Play/Pause" ]
        , button [ onClick HtmlPressedStop ] [ text "Stop" ]
        , button [ onClick HtmlPressedNext ] [ text "Next" ]
        , input
            [ type_ "range"
            , value (String.fromFloat player.volume)
            , onInput (HtmlVolumeRange << Maybe.withDefault player.volume << String.toFloat)
            ]
            []
        , viewPlayerPlaylist player
        ]


viewPlayerPlaylist : Player -> Html Msg
viewPlayerPlaylist player =
    table []
        [ thead [] [ tr [] [ th [] [ text "album" ], th [] [ text "track" ] ] ]
        , tbody []
            (NE.toList
                (NE.indexedMap
                    (\idx track ->
                        if modBy (NE.length player.playlist.tracks) player.idx == idx then
                            tr [ onClick (HtmlPressedPlaylistIdx idx) ]
                                [ td [] [ strong [] [ text track.album ] ]
                                , td [] [ strong [] [ text track.name ] ]
                                ]

                        else
                            tr [ onClick (HtmlPressedPlaylistIdx idx) ]
                                [ td [] [ text track.album ]
                                , td [] [ text track.name ]
                                ]
                    )
                    player.playlist.tracks
                )
            )
        ]


viewPlayerState : PlayerState -> Html Msg
viewPlayerState ps =
    let
        stateString =
            case ps of
                Loading ->
                    "Loading"

                NotLoadedError err ->
                    "Not Loaded Error: " ++ err

                Playing ->
                    "Playing"

                PlayingError err ->
                    "Playing Error: " ++ err

                Paused ->
                    "Pause"

                Stopped ->
                    "Stopped"
    in
    text stateString
