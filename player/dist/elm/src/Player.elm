module Player exposing (Player, PlayerState(..), Playlist, Track, toPlaylists)

import List.Nonempty as NE



{-
   TODO:
   * create playlists by genre/artist/album
   * sort every playlist
-}


type PlayerState
    = Loading
    | NotLoadedError String
    | Playing
    | PlayingError String
    | Paused
    | Stopped


type alias Track =
    { name : String
    , artist : String
    , album : String
    , genre : String
    , blobref : String
    , track : Int
    }


type alias Player =
    { state : PlayerState
    , playlist : Playlist
    , idx : Int
    , volume : Float
    , duration : Float
    , at : Float
    }


type alias Playlist =
    { name : String
    , tracks : NE.Nonempty Track
    }


toPlaylists : NE.Nonempty Track -> NE.Nonempty Playlist
toPlaylists tracks =
    NE.singleton { name = "all", tracks = sortTracks tracks }


sortTracks : NE.Nonempty Track -> NE.Nonempty Track
sortTracks tracks =
    NE.sortWith compareTracks tracks


compareTracks : Track -> Track -> Order
compareTracks s t =
    case compare s.genre t.genre of
        EQ ->
            case compare s.artist t.artist of
                EQ ->
                    case compare s.album t.album of
                        EQ ->
                            compare s.track t.track

                        o ->
                            o

                o ->
                    o

        o ->
            o
