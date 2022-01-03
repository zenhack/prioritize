module Main exposing (main)

import Accessors
import Browser
import Dict exposing (Dict)
import GenAccessors as GA
import Html exposing (..)
import Html.Attributes exposing (checked, class, disabled, for, href, name, selected, type_, value)
import Html.Events exposing (onCheck, onClick, onInput, preventDefaultOn)
import Http
import Json.Decode as D
import Json.Encode as E
import Time
import Utils.Events exposing (onChange)


dayInMilliseconds =
    1000 * 60 * 60 * 24


type alias Flags =
    { now : Int
    , data : String
    , timezoneOffset : Int
    , csrfToken : String
    , dataVersion : Int
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
    , dataVersion : Int
    }


type alias JobForm =
    { title : String
    , period : String
    , urgencyGrowth : UrgencyGrowth
    }


type UrgencyGrowth
    = Linear
    | Quadratic


initJobForm : JobForm
initJobForm =
    { title = ""
    , period = ""
    , urgencyGrowth = Linear
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
                        , urgencyGrowth = jobForm.urgencyGrowth
                        , editing = Nothing
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
            applyUrgency job.urgencyGrowth overDueBy


applyUrgency : UrgencyGrowth -> Int -> Int
applyUrgency urgency x =
    case urgency of
        Linear ->
            x

        Quadratic ->
            if x > 0 then
                x * x

            else
                x


type alias Job =
    { title : String
    , period : Int
    , lastDone : Maybe Time.Posix
    , urgencyGrowth : UrgencyGrowth
    , editing : Maybe JobForm
    }


type alias Accessor super sub =
    Accessors.Relation sub sub sub -> Accessors.Relation super sub sub


type Msg
    = UpdateFormField (Maybe JobId) (JobForm -> JobForm) -- JobId = Nothing means new job.
    | SetShowNotDue Bool
    | NewJob Job
    | JobDone JobId
    | DeleteJob JobId
    | EditJob JobId
    | UpdateJob JobId Job
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
      , dataVersion = flags.dataVersion
      }
    , Cmd.none
    )


view : Model -> Browser.Document Msg
view model =
    { title = "Task List"
    , body =
        [ viewError model.saveError
        , viewJobForm
            { buttonText = "Create"
            , form = model.newJob
            , submit = NewJob
            , id = Nothing
            }
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

                            Http.BadStatus 409 ->
                                "The grain has been updated by another computer or browser tab; please refresh your browser."

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
        (case job.editing of
            Just form ->
                [ viewJobForm
                    { buttonText = "Update"
                    , form = form
                    , submit = UpdateJob id
                    , id = Just id
                    }
                ]

            Nothing ->
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
                , button [ onClick (EditJob id) ] [ text "Edit" ]
                ]
        )


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
                        , preventDefaultOn "click" <|
                            D.succeed
                                ( SetShowNotDue (not model.showNotDue)
                                , True
                                )
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


type alias ViewJobFormArgs =
    { buttonText : String
    , form : JobForm
    , submit : Job -> Msg
    , id : Maybe JobId
    }


viewJobForm : ViewJobFormArgs -> Html Msg
viewJobForm args =
    div [ class "jobForm" ]
        [ div []
            [ label [ for "title" ] [ text "Title: " ]
            , input
                [ class "jobFormInput"
                , name "title"
                , onInput (UpdateFormField args.id << Accessors.set GA.title)
                , value args.form.title
                ]
                []
            ]
        , div []
            [ label [ for "period" ] [ text "Period (days): " ]
            , input
                [ class "jobFormInput"
                , type_ "number"
                , name "period"
                , onInput (UpdateFormField args.id << Accessors.set GA.period)
                , value args.form.period
                ]
                []
            ]
        , div []
            [ label [ for "urgencyGrowth" ] [ text "Urgency growth rate: " ]
            , select
                [ class "jobFormInput"
                , name "urgencyGrowth"
                , onChange
                    (D.map
                        (UpdateFormField args.id << Accessors.set GA.urgencyGrowth)
                        decodeUrgencyGrowth
                    )
                ]
                ([ ( Linear, "linear" )
                 , ( Quadratic, "quadratic" )
                 ]
                    |> List.map
                        (\( urgency, lbl ) ->
                            option
                                [ value lbl
                                , selected (urgency == args.form.urgencyGrowth)
                                ]
                                [ text lbl ]
                        )
                )
            ]
        , button
            [ case makeJob args.form of
                Nothing ->
                    disabled True

                Just job ->
                    onClick (args.submit job)
            ]
            [ text args.buttonText ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetShowNotDue val ->
            ( { model | showNotDue = val }
            , Cmd.none
            )

        UpdateFormField Nothing f ->
            ( { model | newJob = f model.newJob }
            , Cmd.none
            )

        UpdateFormField (Just id) f ->
            ( { model
                | jobs =
                    Dict.update
                        id
                        (Maybe.map
                            (\job -> { job | editing = Maybe.map f job.editing })
                        )
                        model.jobs
              }
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

        EditJob jobId ->
            ( { model | jobs = Dict.update jobId (Maybe.map activateEditForm) model.jobs }
            , Cmd.none
            )

        UpdateJob jobId newJob ->
            let
                m =
                    { model | jobs = Dict.update jobId (Maybe.map (updateJob newJob)) model.jobs }
            in
            ( m, saveData m )

        NewNow now ->
            ( { model | now = now }
            , Cmd.none
            )

        SaveResponse (Ok _) ->
            ( { model
                | saveError = Nothing
                , dataVersion = model.dataVersion + 1
              }
            , Cmd.none
            )

        SaveResponse (Err e) ->
            ( { model | saveError = Just e }
            , Cmd.none
            )


activateEditForm : Job -> Job
activateEditForm job =
    { job
        | editing =
            Just
                { title = job.title
                , period = String.fromInt (job.period // dayInMilliseconds)
                , urgencyGrowth = job.urgencyGrowth
                }
    }


updateJob : Job -> Job -> Job
updateJob newJob oldJob =
    { title = newJob.title
    , period = newJob.period
    , lastDone = oldJob.lastDone
    , urgencyGrowth = newJob.urgencyGrowth
    , editing = Nothing
    }


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
            , Http.header "X-Sandstorm-App-Data-Version" (String.fromInt model.dataVersion)
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
    D.map5 Job
        (D.field "title" D.string)
        (D.field "period" D.int)
        (D.field "lastDone" (D.nullable decodePosix))
        (D.maybe
            (D.field "urgencyGrowth" decodeUrgencyGrowth)
            |> D.map (Maybe.withDefault Linear)
        )
        (D.succeed Nothing)


decodeUrgencyGrowth : D.Decoder UrgencyGrowth
decodeUrgencyGrowth =
    D.string
        |> D.andThen
            (\s ->
                case s of
                    "linear" ->
                        D.succeed Linear

                    "quadratic" ->
                        D.succeed Quadratic

                    _ ->
                        D.fail ("Unexpected growth function: " ++ s)
            )


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
        , ( "urgencyGrowth"
          , encodeUrgencyGrowth job.urgencyGrowth
          )
        ]


encodeUrgencyGrowth : UrgencyGrowth -> E.Value
encodeUrgencyGrowth ug =
    E.string <|
        case ug of
            Linear ->
                "linear"

            Quadratic ->
                "quadratic"


encodePosix : Time.Posix -> E.Value
encodePosix time =
    E.int (Time.posixToMillis time)
