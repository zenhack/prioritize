module Main exposing (main)

import Browser
import Html exposing (..)
import Time


type alias Flags =
    {}


type alias Model =
    { jobs : List Job
    }


type alias Job =
    { title : String
    , period : Int
    , lastDone : Time.Posix
    }


type alias Msg =
    ()


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { jobs = []
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view _ =
    { title = "Hello, World!"
    , body =
        [ p [] [ text "Hello, World!" ]
        ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update () model =
    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
