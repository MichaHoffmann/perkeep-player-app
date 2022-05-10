module Messages exposing(Msg(..))

import Model exposing (PlayerState)

type Msg = 
    PlayerStateChange PlayerState 
  | LoadTracks
  | LoadedTracks
