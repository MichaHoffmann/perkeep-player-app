module Model exposing (Model, init, handlePlay, handlePause, handleStop)

import List.Nonempty exposing (Nonempty, fromList, head, singleton)

import Messages exposing (Msg(..))
import Ports as P

type PlayerState = Playing | Paused | Stopped

type alias Track = 
    { name: String
    , artist: String
    , album: String
    , blobref: String
    }

apiMetaUrl : String
apiMetaUrl = "api/meta"

urlFromBlobRef : String -> String
urlFromBlobRef br = "../ui/download/" ++ br

type alias Player =
    { state: PlayerState
    , activeTrack: Track
    , activePlaylist: Playlist
    }

type alias Playlist =
    { name: String
    , tracks: Nonempty Track
    }

type alias Catalog = 
    { playlists: Nonempty Playlist }

type Model = 
    TracksNotYetLoaded
  | TracksLoaded { player : Player, catalog : Catalog}

init : (Model, Cmd Msg)
init = (TracksNotYetLoaded, fetchTracks)

handlePlay : Model -> (Model, Cmd Msg)
handlePlay mm = case mm of 
  Nothing -> (mm, Cmd.none)
  Just m -> 
    let 
        p = m.player
        np = {p | state = Playing}
    in case m.player.state of
      Playing -> (mm, Cmd.none)
      _ -> (Just { m | player = p}, P.play ())

handlePause : Model -> (Model, Cmd Msg)
handlePause mm = case mm of 
  Nothing -> (mm, Cmd.none)
  Just m -> 
    let 
        p = m.player
        np = {p | state = Paused}
    in case m.player.state of
      Paused -> (mm, Cmd.none)
      _ -> (Just { m | player = p}, P.pause ())

handleStop : Model -> (Model, Cmd Msg)
handleStop mm = case mm of 
  Nothing -> (mm, Cmd.none)
  Just m ->
    let 
        p = m.player
        np = {p | state = Stopped}
    in case m.player.state of
      Stopped -> (mm, Cmd.none)
      _ -> (Just { m | player = p}, P.stop ())

makeCatalog : Nonempty Track -> Catalog
makeCatalog tracks = { playlists = singleton { name = "default", tracks = tracks } }
