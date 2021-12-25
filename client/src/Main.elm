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
    , csrfToken : String
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
    , csrfToken : String
    , saveError : Maybe Http.Error
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
            -- overdue. N.B. there is no "max integer" constant in elm,
            -- and we probably don't want to get too close to that anyway,
            -- as it would run the risk of integer overflow. Instead, we
            -- just pick a number that is big enough for practical purposes:
            -- roughly ten years.
            10 * 365 * dayInMilliseconds

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
      , csrfToken = flags.csrfToken
      , saveError = Nothing
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    { title = "Task List"
    , body =
        [ viewError model.saveError
        , viewNewJob model.newJob
        , viewJobs model
        ]
    }


viewError : Maybe Http.Error -> Html msg
viewError maybeErr =
    case maybeErr of
        Nothing ->
            div [] []

        Just err ->
            div [ class "errorBox" ]
                [ p []
                    [ text "Error saving data: "
                    , text <|
                        case err of
                            Http.BadUrl url ->
                                -- Should never happen; indicative of a bug in our code.
                                "BUG: provided bad url: " ++ url

                            Http.Timeout ->
                                "request timed out"

                            Http.NetworkError ->
                                "network error"

                            Http.BadStatus status ->
                                "the server returned an error: " ++ String.fromInt status

                            Http.BadBody msg ->
                                -- Should never happen, since we use expectWhatever.
                                "Parsing the body failed: " ++ msg
                    ]
                ]


viewJob : { r | timezone : Time.Zone, now : Time.Posix } -> JobId -> Job -> Html Msg
viewJob model id job =
    let
        now =
            truncateToDay model.timezone model.now

        lastDone =
            Maybe.map (truncateToDay model.timezone) job.lastDone

        periodInDays =
            job.period // dayInMilliseconds
    in
    div [ class "job" ]
        [ h1 [] [ text job.title ]
        , p []
            [ text "Due every "
            , text (String.fromInt periodInDays)
            , text " "
            , text <| pluralizeDays periodInDays
            ]
        , case lastDone of
            Nothing ->
                p [] [ text "Never done before" ]

            Just done ->
                let
                    lastDoneDiff =
                        (Time.posixToMillis now - Time.posixToMillis done) // dayInMilliseconds
                in
                p []
                    [ text "Last done "
                    , text (String.fromInt lastDoneDiff)
                    , text " "
                    , text <| pluralizeDays lastDoneDiff
                    , text " ago"
                    ]
        , button [ onClick (JobDone id) ] [ text "Done" ]
        , button [ onClick (DeleteJob id) ] [ text "Delete" ]
        ]


pluralizeDays : Int -> String
pluralizeDays =
    pluralize "day" "days"


pluralize : a -> a -> Int -> a
pluralize singular plural count =
    if count == 1 then
        singular

    else
        plural


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

        SaveResponse (Ok _) ->
            ( { model | saveError = Nothing }
            , Cmd.none
            )

        SaveResponse (Err e) ->
            ( { model | saveError = Just e }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    -- Update every 15 minutes. We only actually care about day
    -- changeovers, so we don't check very often.
    Time.every (1000 * 60 * 15) NewNow


saveData : Model -> Cmd Msg
saveData model =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "X-CSRF-Token" model.csrfToken
            ]
        , url = "/data"
        , body = Http.jsonBody (encodeJobs model.jobs)
        , expect = Http.expectWhatever SaveResponse
        , timeout = Nothing
        , tracker = Nothing
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
