port module Ports exposing (FromJsMsg(..), ToJsMsg(..), receiveMsg, sendMsg)

import Json.Decode as JD
import Json.Encode as JE


port audioPortToJs : JE.Value -> Cmd msg


port audioPortFromJs : (JE.Value -> msg) -> Sub msg


type ToJsMsg
    = ToJsInit String
    | ToJsPlay
    | ToJsPause
    | ToJsStop
    | ToJsVolume Float
    | ToJsSeekTo Float
    | ToJsGetSeekState


encodeToJsMsg : ToJsMsg -> JE.Value
encodeToJsMsg msg =
    case msg of
        ToJsInit url ->
            JE.object
                [ ( "type", JE.string "init" )
                , ( "url", JE.string url )
                ]

        ToJsPlay ->
            JE.object
                [ ( "type", JE.string "play" ) ]

        ToJsPause ->
            JE.object
                [ ( "type", JE.string "pause" ) ]

        ToJsStop ->
            JE.object
                [ ( "type", JE.string "stop" ) ]

        ToJsVolume vol ->
            JE.object
                [ ( "type", JE.string "volume" )
                , ( "volume", JE.float vol )
                ]

        ToJsGetSeekState ->
            JE.object
                [ ( "type", JE.string "getseek" ) ]

        ToJsSeekTo seek ->
            JE.object
                [ ( "type", JE.string "seekto" )
                , ( "seek", JE.float seek )
                ]


type FromJsMsg
    = FromJsOnInitialized
    | FromJsOnLoad Float
    | FromJsOnLoadError String
    | FromJsOnPlay
    | FromJsOnPlayError String
    | FromJsOnPause
    | FromJsOnStop
    | FromJsOnEnd
    | FromJsOnVolume Float
    | FromJsSeekState Float
    | FromJsBadMessage String


decodeFromJsMsg : JD.Decoder FromJsMsg
decodeFromJsMsg =
    JD.field "type" JD.string
        |> JD.andThen
            (\t ->
                case t of
                    "oninitialized" ->
                        JD.succeed FromJsOnInitialized

                    "onload" ->
                        JD.field "duration" JD.float
                            |> JD.andThen
                                (\dur -> JD.succeed (FromJsOnLoad dur))

                    "onloaderror" ->
                        JD.field "error" JD.string
                            |> JD.andThen
                                (\e -> JD.succeed (FromJsOnLoadError e))

                    "onplay" ->
                        JD.succeed FromJsOnPlay

                    "onplayerror" ->
                        JD.field "error" JD.string
                            |> JD.andThen
                                (\e -> JD.succeed (FromJsOnPlayError e))

                    "onpause" ->
                        JD.succeed FromJsOnPause

                    "onstop" ->
                        JD.succeed FromJsOnStop

                    "onend" ->
                        JD.succeed FromJsOnEnd

                    "onvolume" ->
                        JD.field "volume" JD.float
                            |> JD.andThen
                                (\vol -> JD.succeed (FromJsOnVolume vol))

                    "seekstate" ->
                        JD.field "seek" JD.float
                            |> JD.andThen
                                (\seek -> JD.succeed (FromJsSeekState seek))

                    _ ->
                        JD.succeed (FromJsBadMessage ("unknown message type: " ++ t))
            )


sendMsg : ToJsMsg -> Cmd msg
sendMsg msg =
    encodeToJsMsg msg |> audioPortToJs


receiveMsg : (FromJsMsg -> msg) -> Sub msg
receiveMsg msg =
    audioPortFromJs
        (\val ->
            case JD.decodeValue decodeFromJsMsg val of
                Ok event ->
                    msg event

                Err decodeErr ->
                    msg (FromJsBadMessage (JD.errorToString decodeErr))
        )
