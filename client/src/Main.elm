module Main exposing (main)

import Accessors
import Browser
import Dict exposing (Dict)
import GenAccessors as GA
import Html exposing (..)
import Html.Attributes exposing (checked, class, disabled, for, href, name, type_, value)
import Html.Events exposing (onCheck, onClick, onInput)
import Http
import Json.Decode as D
import Json.Encode as E
import Time


dayInMilliseconds =
    1000 * 60 * 60 * 24


type alias Flags =
    { now : Int
    , data : String
    , timezoneOffset : Int
    }


type alias JobId =
    Int


type alias Model =
    { jobs : Dict JobId Job
    , newJob : JobForm
    , nextId : JobId
    , now : Time.Posix
    , showNotDue : Bool
    , timezone : Time.Zone
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


truncateToDay : Time.Zone -> Time.Posix -> Time.Posix
truncateToDay zone time =
    let
        s =
            Time.toSecond zone time

        m =
            Time.toMinute zone time

        h =
            Time.toHour zone time

        millis =
            ((((h * 60) + m) * 60) + s) * 1000
    in
    Time.millisToPosix (Time.posixToMillis time - millis)


overDue : Time.Zone -> Time.Posix -> Job -> Int
overDue here now job =
    case job.lastDone of
        Nothing ->
            -- If the job has literally never been done, treat it as very
            -- overdue. TODO: figure out if elm has a max int constant
            -- somewhere.
            1000 * dayInMilliseconds

        Just lastDone ->
            let
                todayMillis =
                    Time.posixToMillis (truncateToDay here now)

                dueMillis =
                    Time.posixToMillis (truncateToDay here lastDone) + job.period

                overDueBy =
                    todayMillis - dueMillis
            in
            overDueBy


type alias Job =
    { title : String
    , period : Int
    , lastDone : Maybe Time.Posix
    }


type alias Accessor super sub =
    Accessors.Relation sub sub sub -> Accessors.Relation super sub sub


type Msg
    = UpdateFormField (Accessor JobForm String) String
    | SetShowNotDue Bool
    | NewJob Job
    | JobDone JobId
    | DeleteJob JobId
    | NewNow Time.Posix
    | SaveResponse (Result Http.Error ())


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        jobs =
            case D.decodeString decodeJobs flags.data of
                Ok v ->
                    v

                Err _ ->
                    Dict.empty
    in
    ( { jobs = jobs
      , newJob = initJobForm
      , nextId =
            -- One greater than the largest id so far:
            List.foldl max 0 (Dict.keys jobs) + 1
      , now = Time.millisToPosix flags.now
      , showNotDue = False
      , timezone = Time.customZone flags.timezoneOffset []
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    { title = "Task List"
    , body =
        [ viewNewJob model.newJob
        , viewJobs model
        ]
    }


viewJob : { r | now : Time.Posix } -> JobId -> Job -> Html Msg
viewJob { now } id job =
    div [ class "job" ]
        [ h1 [] [ text job.title ]
        , p []
            [ text "Due every "
            , text (String.fromInt (job.period // dayInMilliseconds))
            , text " day(s)"
            ]
        , case job.lastDone of
            Nothing ->
                p [] [ text "Never done before" ]

            Just lastDone ->
                let
                    lastDoneDiff =
                        Time.posixToMillis now - Time.posixToMillis lastDone
                in
                p []
                    [ text "Last done "
                    , text (String.fromInt (lastDoneDiff // dayInMilliseconds))
                    , text " day(s) ago"
                    ]
        , button [ onClick (JobDone id) ] [ text "Done" ]
        , button [ onClick (DeleteJob id) ] [ text "Delete" ]
        ]


viewJobs : Model -> Html Msg
viewJobs model =
    let
        ( overDueJobs, notDueJobs ) =
            Dict.toList model.jobs
                |> List.map
                    (\( id, job ) ->
                        { overDueBy = overDue model.timezone model.now job
                        , html = viewJob model id job
                        }
                    )
                |> List.sortBy .overDueBy
                |> List.reverse
                |> List.partition (\v -> v.overDueBy >= 0)
                |> Tuple.mapBoth (List.map .html) (List.map .html)

        jobList =
            ol [ class "jobList" ]
    in
    div []
        (List.concat
            [ [ jobList overDueJobs ]
            , [ input
                    [ name "showNotDue"
                    , type_ "checkbox"
                    , checked model.showNotDue
                    , onCheck SetShowNotDue
                    ]
                    []
              , label
                    [ for "showNotDue" ]
                    [ a
                        [ href "#"
                        , class "showNotDue"
                        , onClick (SetShowNotDue (not model.showNotDue))
                        ]
                        [ text "Show not yet due" ]
                    ]
              ]
            , if model.showNotDue then
                [ jobList notDueJobs ]

              else
                []
            ]
        )


viewNewJob : JobForm -> Html Msg
viewNewJob jobForm =
    div []
        [ div []
            [ label [ for "title" ] [ text "Title: " ]
            , input
                [ name "title"
                , onInput (UpdateFormField GA.title)
                , value jobForm.title
                ]
                []
            ]
        , div []
            [ label [ for "period" ] [ text "Period (days): " ]
            , input
                [ type_ "number"
                , name "peroid"
                , onInput (UpdateFormField GA.period)
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
        SetShowNotDue val ->
            ( { model | showNotDue = val }
            , Cmd.none
            )

        UpdateFormField accessor value ->
            ( Accessors.set (GA.newJob << accessor) value model
            , Cmd.none
            )

        NewJob job ->
            let
                m =
                    { model
                        | jobs = Dict.insert model.nextId job model.jobs
                        , nextId = model.nextId + 1
                        , newJob = initJobForm
                    }
            in
            ( m, saveData m )

        JobDone jobId ->
            let
                m =
                    { model
                        | jobs =
                            Dict.update jobId
                                (Maybe.map (\job -> { job | lastDone = Just model.now }))
                                model.jobs
                    }
            in
            ( m, saveData m )

        DeleteJob jobId ->
            let
                m =
                    { model | jobs = Dict.remove jobId model.jobs }
            in
            ( m, saveData m )

        NewNow now ->
            ( { model | now = now }
            , Cmd.none
            )

        SaveResponse _ ->
            -- TODO: react in some way. Probably should report errors.
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    -- Update every 15 minutes. We only actually care about day
    -- changeovers, so we don't check very often.
    Time.every (1000 * 60 * 15) NewNow


saveData : Model -> Cmd Msg
saveData model =
    Http.post
        { url = "/data"
        , body = Http.jsonBody (encodeJobs model.jobs)
        , expect = Http.expectWhatever SaveResponse
        }


main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


decodeJobs : D.Decoder (Dict JobId Job)
decodeJobs =
    D.field "jobs" (decodeDict D.int decodeJob)


decodeDict : D.Decoder comparable -> D.Decoder a -> D.Decoder (Dict comparable a)
decodeDict decodeK decodeV =
    D.list (decodeKv decodeK decodeV)
        |> D.map Dict.fromList


decodeKv : D.Decoder a -> D.Decoder b -> D.Decoder ( a, b )
decodeKv decodeK decodeV =
    D.map2 (\k v -> ( k, v ))
        (D.field "k" decodeK)
        (D.field "v" decodeV)


decodeJob : D.Decoder Job
decodeJob =
    D.map3 Job
        (D.field "title" D.string)
        (D.field "period" D.int)
        (D.field "lastDone" (D.nullable decodePosix))


decodePosix : D.Decoder Time.Posix
decodePosix =
    D.map Time.millisToPosix D.int


encodeJobs : Dict JobId Job -> E.Value
encodeJobs jobs =
    E.object [ ( "jobs", encodeDict E.int encodeJob jobs ) ]


encodeDict : (k -> E.Value) -> (v -> E.Value) -> Dict k v -> E.Value
encodeDict encodeK encodeV d =
    Dict.toList d
        |> E.list (\( k, v ) -> encodeKv (encodeK k) (encodeV v))


encodeKv : E.Value -> E.Value -> E.Value
encodeKv k v =
    E.object
        [ ( "k", k )
        , ( "v", v )
        ]


encodeJob : Job -> E.Value
encodeJob job =
    E.object
        [ ( "title", E.string job.title )
        , ( "period", E.int job.period )
        , ( "lastDone"
          , case job.lastDone of
                Nothing ->
                    E.null

                Just time ->
                    encodePosix time
          )
        ]


encodePosix : Time.Posix -> E.Value
encodePosix time =
    E.int (Time.posixToMillis time)
