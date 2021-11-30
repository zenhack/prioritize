module Main exposing (main)

import Accessors
import Browser
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (disabled, for, name, type_, value)
import Html.Events exposing (onClick, onInput)
import Time


dayInMilliseconds =
    1000 * 60 * 60 * 24


type alias Flags =
    {}


type alias JobId =
    Int


type alias Model =
    { jobs : Dict JobId Job
    , newJob : JobForm
    , nextId : JobId
    , now : Time.Posix
    }


type alias JobForm =
    { title : String
    , period : String
    }


initJobForm : JobForm
initJobForm =
    { title = ""
    , period = ""
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

            Just periodDays ->
                if periodDays < 1 then
                    Nothing

                else
                    Just
                        { period = periodDays * dayInMilliseconds
                        , title = jobForm.title
                        , lastDone = Nothing
                        }


overDue : Time.Posix -> Job -> Maybe Int
overDue now job =
    case job.lastDone of
        Nothing ->
            Just 0

        Just lastDone ->
            let
                nowMillis =
                    Time.posixToMillis now

                dueMillis =
                    Time.posixToMillis lastDone + job.period

                overDueBy =
                    nowMillis - dueMillis
            in
            if overDueBy < 0 then
                Nothing

            else
                Just overDueBy


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
    | JobDone JobId
    | NewNow Time.Posix


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { jobs = Dict.empty
      , newJob = initJobForm
      , nextId = 0
      , now = Time.millisToPosix 0
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    { title = "Task List"
    , body =
        [ viewJobs model
        , viewNewJob model.newJob
        ]
    }


viewJob : JobId -> Job -> Html Msg
viewJob id job =
    div []
        [ p [] [ text "Title: ", text job.title ]
        , button [ onClick (JobDone id) ] [ text "Done" ]
        ]


viewJobs : Model -> Html Msg
viewJobs model =
    let
        jobsHtmlByDue =
            Dict.toList model.jobs
                |> List.filterMap
                    (\( id, job ) ->
                        overDue model.now job
                            |> Maybe.map
                                (\amount ->
                                    { overDueBy = amount
                                    , html = viewJob id job
                                    }
                                )
                    )
                |> List.sortBy .overDueBy
                |> List.reverse
                |> List.map .html
    in
    ol [] jobsHtmlByDue


viewNewJob : JobForm -> Html Msg
viewNewJob jobForm =
    div []
        [ div []
            [ label [ for "title" ] [ text "Title: " ]
            , input
                [ name "title"
                , onInput (UpdateFormField recordTitle)
                , value jobForm.title
                ]
                []
            ]
        , div []
            [ label [ for "period" ] [ text "Period (days): " ]
            , input
                [ type_ "number"
                , name "peroid"
                , onInput (UpdateFormField recordPeriod)
                , value jobForm.period
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
            ( { model
                | jobs = Dict.insert model.nextId job model.jobs
                , nextId = model.nextId + 1
                , newJob = initJobForm
              }
            , Cmd.none
            )

        JobDone jobId ->
            ( { model
                | jobs =
                    Dict.update jobId
                        (Maybe.map (\job -> { job | lastDone = Just model.now }))
                        model.jobs
              }
            , Cmd.none
            )

        NewNow now ->
            ( { model | now = now }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 3000 NewNow


main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
