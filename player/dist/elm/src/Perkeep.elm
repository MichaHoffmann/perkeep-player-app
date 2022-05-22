module Perkeep exposing (getTracks, urlFromBlobRef)

import Http
import Json.Decode as JD
import List.Nonempty as NE
import Player exposing (Track)
import Task


apiMetaUrl : String
apiMetaUrl =
    "api/meta"


urlFromBlobRef : String -> String
urlFromBlobRef br =
    "../ui/download/" ++ br


getTracks : Task.Task Http.Error (NE.Nonempty Track)
getTracks =
    Http.task
        { method = "GET"
        , headers = []
        , url = apiMetaUrl
        , body = Http.emptyBody
        , resolver = Http.stringResolver <| handleJsonResponse <| nonEmptyTracksDecoder
        , timeout = Nothing
        }


nonEmptyTracksDecoder : JD.Decoder (NE.Nonempty Track)
nonEmptyTracksDecoder =
    let
        checkNonEmpty tracks =
            case NE.fromList tracks of
                Just ts ->
                    JD.succeed ts

                Nothing ->
                    JD.fail "Expected list of tracks to be not empty"

        trackDecoder =
            JD.map6 Track
                (JD.field "Title" JD.string)
                (JD.field "Artist" JD.string)
                (JD.field "Album" JD.string)
                (JD.field "Genre" JD.string)
                (JD.field "BlobRef" JD.string)
                (JD.field "Track" JD.int)
    in
    JD.list trackDecoder |> JD.andThen checkNonEmpty


handleJsonResponse : JD.Decoder a -> Http.Response String -> Result Http.Error a
handleJsonResponse decoder response =
    case response of
        Http.BadUrl_ url ->
            Err (Http.BadUrl url)

        Http.Timeout_ ->
            Err Http.Timeout

        Http.BadStatus_ { statusCode } _ ->
            Err (Http.BadStatus statusCode)

        Http.NetworkError_ ->
            Err Http.NetworkError

        Http.GoodStatus_ _ body ->
            case JD.decodeString decoder body of
                Err _ ->
                    Err (Http.BadBody body)

                Ok result ->
                    Ok result
