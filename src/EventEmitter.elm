effect module EventEmitter
    where { command = MyCmd }
    exposing
        ( Id
        , listen
        , listenOnce
        , unlisten
        , trigger
        , receive
        , receiveOnce
        , unreceive
        , send
        )

{-|
    Event Emitter

@docs Id, listen, listenOnce, unlisten, trigger, receive, receiveOnce, unreceive, send
-}

import Dict exposing (..)
import Task exposing (Task)


-- API


{-| EventEmitter id
-}
type alias Id =
    String


type MyCmd msg
    = Listen Id (EventTagger msg)
    | ListenOnce Id (EventTagger msg)
    | Unlisten Id (EventTagger msg)
    | Trigger Id
    | Receive Id (SendTagger msg)
    | ReceiveOnce Id (SendTagger msg)
    | Unreceive Id (SendTagger msg)
    | Send Id String



-- Taggers


{-| Event Tagger
-}
type alias EventTagger msg =
    Id -> msg


{-| Send completion tagger
-}
type alias SendTagger msg =
    String -> Id -> msg


type alias SubscriberState eventTagger =
    { tagger : eventTagger
    , once : Bool
    }


{-| Effects manager state
-}
type alias State msg =
    { listeners : Dict Id (List (SubscriberState (EventTagger msg)))
    , receivers : Dict Id (List (SubscriberState (SendTagger msg)))
    }



-- Cmds


compose2 : (c -> d) -> (a -> b -> c) -> a -> b -> d
compose2 f2 f1 a =
    (<<) f2 <| f1 a


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap f cmd =
    case cmd of
        Listen eventId tagger ->
            Listen eventId (f << tagger)

        ListenOnce eventId tagger ->
            ListenOnce eventId (f << tagger)

        Unlisten eventId tagger ->
            Unlisten eventId (f << tagger)

        Trigger eventId ->
            Trigger eventId

        Receive eventId tagger ->
            Receive eventId (compose2 f tagger)

        ReceiveOnce eventId tagger ->
            ReceiveOnce eventId (compose2 f tagger)

        Unreceive eventId tagger ->
            Unreceive eventId (compose2 f tagger)

        Send eventId payload ->
            Send eventId payload


{-| Listen to id
-}
listen : EventTagger msg -> Id -> Cmd msg
listen tagger eventId =
    command (Listen eventId tagger)


{-| Listen ONCE to id
-}
listenOnce : EventTagger msg -> Id -> Cmd msg
listenOnce tagger eventId =
    command (ListenOnce eventId tagger)


{-| Stop listening to id
-}
unlisten : EventTagger msg -> Id -> Cmd msg
unlisten tagger eventId =
    command (Unlisten eventId tagger)


{-| Trigger event
-}
trigger : Id -> Cmd msg
trigger eventId =
    command (Trigger eventId)


{-| Receive data from  id
-}
receive : SendTagger msg -> Id -> Cmd msg
receive tagger eventId =
    command (Receive eventId tagger)


{-| Receive ONCE data from  id
-}
receiveOnce : SendTagger msg -> Id -> Cmd msg
receiveOnce tagger eventId =
    command (ReceiveOnce eventId tagger)


{-| Stop receving data from id
-}
unreceive : SendTagger msg -> Id -> Cmd msg
unreceive tagger eventId =
    command (Unreceive eventId tagger)


{-| Send data to all receivers on id
-}
send : Id -> String -> Cmd msg
send eventId payload =
    command (Send eventId payload)



-- Operators


(|?>) : Maybe a -> (a -> b) -> Maybe b
(|?>) =
    flip Maybe.map


(?=) : Maybe a -> a -> a
(?=) =
    flip Maybe.withDefault


(?) : Bool -> ( a, a ) -> a
(?) bool ( t, f ) =
    if bool then
        t
    else
        f


(&>) : Task x a -> Task x b -> Task x b
(&>) t1 t2 =
    t1 |> Task.andThen (\_ -> t2)



-- Init


init : Task Never (State msg)
init =
    Task.succeed <| State Dict.empty Dict.empty



-- effect managers API


onEffects : Platform.Router msg (Msg msg) -> List (MyCmd msg) -> State msg -> Task Never (State msg)
onEffects router cmds state =
    let
        handleOneCmd state cmd tasks =
            let
                ( task, newState ) =
                    handleCmd router state cmd
            in
                ( task :: tasks, newState )

        ( tasks, cmdState ) =
            List.foldl (\cmd ( tasks, state ) -> handleOneCmd state cmd tasks) ( [], state ) cmds
    in
        Task.sequence (List.reverse <| tasks)
            &> Task.succeed cmdState


subscribe : Id -> Bool -> tagger -> (State msg -> Dict Id (List (SubscriberState tagger))) -> (State msg -> Dict Id (List (SubscriberState tagger)) -> State msg) -> State msg -> ( Task Never (), State msg )
subscribe eventId once tagger getter setter state =
    let
        subscriberState =
            { tagger = tagger
            , once = once
            }

        subscribers =
            getter state
    in
        ( Task.succeed (), setter state <| Dict.insert eventId (subscriberState :: (Dict.get eventId subscribers ?= [])) subscribers )


unsubscribe : Id -> tagger -> (tagger -> String -> msg) -> (State msg -> Dict Id (List (SubscriberState tagger))) -> (State msg -> Dict Id (List (SubscriberState tagger)) -> State msg) -> State msg -> ( Task Never (), State msg )
unsubscribe eventId tagger bindTagger getter setter state =
    let
        subscribers =
            getter state
    in
        Dict.get eventId subscribers
            |?> (\subscrberStates ->
                    let
                        msg =
                            (bindTagger tagger) ""

                        remainingSubscribers =
                            subscrberStates
                                |> List.filter (\subscriberState -> (bindTagger subscriberState.tagger) "" /= msg)
                    in
                        ( Task.succeed (), setter state <| (remainingSubscribers == []) ? ( Dict.remove eventId subscribers, Dict.insert eventId remainingSubscribers subscribers ) )
                )
            ?= ( Task.succeed (), state )


publish : Platform.Router msg (Msg msg) -> Id -> (tagger -> String -> msg) -> (State msg -> Dict Id (List (SubscriberState tagger))) -> (State msg -> Dict Id (List (SubscriberState tagger)) -> State msg) -> State msg -> ( Task Never (), State msg )
publish router eventId bindTagger getter setter state =
    let
        subscribers =
            getter state

        task =
            (Dict.get eventId subscribers ?= [])
                |> List.map .tagger
                |> List.map (\tagger -> Platform.sendToApp router ((bindTagger tagger) eventId))
                |> List.foldl (&>) (Task.succeed ())

        remainingSubscribers =
            (Dict.get eventId subscribers ?= [])
                |> List.filter (not << .once)
    in
        ( task, setter state ((remainingSubscribers == []) ? ( Dict.remove eventId subscribers, Dict.insert eventId remainingSubscribers subscribers )) )


handleCmd : Platform.Router msg (Msg msg) -> State msg -> MyCmd msg -> ( Task Never (), State msg )
handleCmd router state cmd =
    let
        listenersSetter state listeners =
            { state | listeners = listeners }

        receiversSetter state receivers =
            { state | receivers = receivers }
    in
        case cmd of
            Listen eventId tagger ->
                subscribe eventId False tagger .listeners listenersSetter state

            ListenOnce eventId tagger ->
                subscribe eventId True tagger .listeners listenersSetter state

            Unlisten eventId tagger ->
                unsubscribe eventId tagger identity .listeners listenersSetter state

            Trigger eventId ->
                publish router eventId identity .listeners listenersSetter state

            Receive eventId tagger ->
                subscribe eventId False tagger .receivers receiversSetter state

            ReceiveOnce eventId tagger ->
                subscribe eventId True tagger .receivers receiversSetter state

            Unreceive eventId tagger ->
                unsubscribe eventId tagger (\tagger -> tagger "") .receivers receiversSetter state

            Send eventId payload ->
                publish router eventId (\tagger -> tagger payload) .receivers receiversSetter state


type Msg msg
    = Nop


onSelfMsg : Platform.Router msg (Msg msg) -> Msg msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    Task.succeed state
