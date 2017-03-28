port module Main exposing (..)

import EventEmitter exposing (..)
import Process
import Task
import Time exposing (Time)


{- REMOVE WHEN COMPILER BUG IS FIXED -}

import Json.Decode


port exitApp : Float -> Cmd msg


port externalStop : (() -> msg) -> Sub msg


main : Program Never Model Msg
main =
    Platform.program
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    {}


type Msg
    = Unlisten Id
    | Trigger Id
    | ListenTriggered Id
    | UnlistenTriggered Id
    | ListenOnceTriggered Id
    | Unreceive Id
    | Send String Id
    | ReceiveReceived String Id
    | UnreceiveRecieved String Id
    | ReceiveOnceReceived String Id
    | StopTest
    | AbortTest


listenEventId : Id
listenEventId =
    "listen"


listenOnceEventId : Id
listenOnceEventId =
    "listenOnce"


unlistenEventId : Id
unlistenEventId =
    "unlisten"


init : ( Model, Cmd Msg )
init =
    {}
        ! [ EventEmitter.listen ListenTriggered listenEventId
          , EventEmitter.listen UnlistenTriggered unlistenEventId
          , EventEmitter.listenOnce ListenOnceTriggered listenOnceEventId
          , EventEmitter.receive ReceiveReceived listenEventId
          , EventEmitter.receive UnreceiveRecieved unlistenEventId
          , EventEmitter.receiveOnce ReceiveOnceReceived listenOnceEventId
          , delayMsg 100 <| Unlisten unlistenEventId
          , delayMsg 200 <| Trigger listenEventId
          , delayMsg 300 <| Trigger unlistenEventId
          , delayMsg 400 <| Unreceive unlistenEventId
          , delayMsg 500 <| Send "PAYLOAD" listenEventId
          , delayMsg 600 <| Send "PAYLOAD" unlistenEventId
          , delayMsg 700 <| Trigger listenOnceEventId
          , delayMsg 800 <| Send "PAYLOAD" listenOnceEventId
          , delayMsg 900 <| Trigger listenOnceEventId
          , delayMsg 1000 <| Send "PAYLOAD" listenOnceEventId
          , delayMsg 1100 <| StopTest
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
                    ! [ EventEmitter.unlisten UnlistenTriggered eventId
                      ]

        Trigger eventId ->
            let
                message =
                    Debug.log "Trigger" eventId
            in
                model
                    ! [ EventEmitter.trigger eventId
                      ]

        ListenTriggered eventId ->
            let
                message =
                    Debug.log "-->ListenTriggered" eventId
            in
                model ! []

        UnlistenTriggered eventId ->
            let
                message =
                    Debug.log "-->UnlistenTriggered (Should Never Get Here)!!!!" eventId
            in
                model ! []

        ListenOnceTriggered eventId ->
            let
                message =
                    Debug.log "-->ListenOnceTriggered (Should only be ONCE)" eventId
            in
                model ! []

        Unreceive eventId ->
            let
                message =
                    Debug.log "Unreceive" eventId
            in
                model
                    ! [ EventEmitter.unreceive UnreceiveRecieved eventId
                      ]

        Send payload eventId ->
            let
                message =
                    Debug.log "Send" ( eventId, payload )
            in
                model
                    ! [ EventEmitter.send eventId payload
                      ]

        ReceiveReceived payload eventId ->
            let
                message =
                    Debug.log "-->SendReceived" ( eventId, payload )
            in
                model ! []

        UnreceiveRecieved payload eventId ->
            let
                message =
                    Debug.log "-->UnlistenTriggered (Should Never Get Here)!!!!" ( eventId, payload )
            in
                model ! []

        ReceiveOnceReceived payload eventId ->
            let
                message =
                    Debug.log "-->ReceiveOnceReceived (Should only be ONCE)" ( eventId, payload )
            in
                model ! []

        AbortTest ->
            model ! [ exitApp -1 ]

        StopTest ->
            model ! [ exitApp 0 ]


subscriptions : Model -> Sub Msg
subscriptions model =
    externalStop <| always AbortTest



-- UTILITIES


delayMsg : Time -> Msg -> Cmd Msg
delayMsg time msg =
    Process.sleep time
        |> Task.perform (\_ -> msg)
