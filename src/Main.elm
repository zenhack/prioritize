module Main exposing (main)

import Accessors
import Browser
import Html exposing (..)
import Html.Attributes exposing (disabled, for, name, type_)
import Html.Events exposing (onClick, onInput)
import Time


type alias Flags =
    {}


type alias Model =
    { jobs : List Job
    , newJob : JobForm
    }


type alias JobForm =
    { title : String
    , period : String
    }


recordNewJob =
    Accessors.makeOneToOne .newJob (\c r -> { r | newJob = c r.newJob })


recordTitle =
    Accessors.makeOneToOne .title (\c r -> { r | title = c r.title })


recordPeriod =
    Accessors.makeOneToOne .period (\c r -> { r | period = c r.period })


makeJob : JobForm -> Maybe Job
makeJob jobForm =
    if jobForm.title == "" then
        Nothing

    else
        case String.toInt jobForm.period of
            Nothing ->
                Nothing

            Just period ->
                if period < 1 then
                    Nothing

                else
                    Just
                        { period = period
                        , title = jobForm.title
                        , lastDone = Nothing
                        }


type alias Job =
    { title : String
    , period : Int
    , lastDone : Maybe Time.Posix
    }


type alias Accessor super sub =
    Accessors.Relation sub sub sub -> Accessors.Relation super sub sub


type Msg
    = UpdateFormField (Accessor JobForm String) String
    | NewJob Job


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { jobs = []
      , newJob =
            { title = ""
            , period = ""
            }
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    { title = "Hello, World!"
    , body =
        [ p [] [ text "Hello, World!" ]
        , viewJobs model
        , viewNewJob model.newJob
        ]
    }


viewJob : Job -> Html Msg
viewJob job =
    div []
        [ p [] [ text "Title: ", text job.title ]
        ]


viewJobs : Model -> Html Msg
viewJobs model =
    ol []
        (List.map
            (\job -> li [] [ viewJob job ])
            model.jobs
        )


viewNewJob : JobForm -> Html Msg
viewNewJob jobForm =
    div []
        [ div []
            [ label [ for "title" ] [ text "Title: " ]
            , input
                [ name "title"
                , onInput (UpdateFormField recordTitle)
                ]
                []
            ]
        , div []
            [ label [ for "period" ] [ text "Period (days): " ]
            , input
                [ type_ "number"
                , name "peroid"
                , onInput (UpdateFormField recordPeriod)
                ]
                []
            ]
        , button
            [ case makeJob jobForm of
                Nothing ->
                    disabled True

                Just job ->
                    onClick (NewJob job)
            ]
            [ text "Create" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateFormField accessor value ->
            ( Accessors.set (recordNewJob << accessor) value model
            , Cmd.none
            )

        NewJob job ->
            ( { model | jobs = job :: model.jobs }
            , Cmd.none
            )


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
