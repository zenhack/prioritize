module Utils.Events exposing (onChange)

{-| Html events with no wrappers in the html package.
-}

import Html
import Html.Events exposing (on)
import Json.Decode as D


onChange : D.Decoder a -> Html.Attribute a
onChange decoder =
    on "change" (D.field "target" (D.field "value" decoder))
