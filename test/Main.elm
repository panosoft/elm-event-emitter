module Main exposing (..)

import EventEmitter exposing (..)
import Process
import Task
import Time exposing (Time)


main : Program Never Model Msg
main =
    Platform.program
        { init = init
        , update = update
        , subscriptions = always Sub.none
        }


type alias Model =
    {}


type Msg
    = Unlisten Id
    | Trigger Id
    | EventTriggered Id
    | UnlistenEventTriggered Id


listenEventId : Id
listenEventId =
    "listen"


unlistenEventId : Id
unlistenEventId =
    "unlisten"


init : ( Model, Cmd Msg )
init =
    {}
        ! [ EventEmitter.listen EventTriggered listenEventId
          , EventEmitter.listen UnlistenEventTriggered unlistenEventId
          , delayMsg 100 <| Unlisten unlistenEventId
          , delayMsg 200 <| Trigger listenEventId
          , delayMsg 200 <| Trigger unlistenEventId
          ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Unlisten eventId ->
            let
                message =
                    Debug.log "Unlisten" eventId
            in
                model
                    ! [ EventEmitter.unlisten UnlistenEventTriggered eventId
                      ]

        Trigger eventId ->
            let
                message =
                    Debug.log "Trigger" eventId
            in
                model
                    ! [ EventEmitter.trigger eventId
                      ]

        EventTriggered eventId ->
            let
                message =
                    Debug.log "EventTriggered" eventId
            in
                model ! []

        UnlistenEventTriggered eventId ->
            let
                message =
                    Debug.log "UnlistenEventTriggered (Should Never Get Here)" eventId
            in
                model ! []



-- UTILITIES


delayMsg : Time -> Msg -> Cmd Msg
delayMsg time msg =
    Process.sleep time
        |> Task.perform (\_ -> msg)
