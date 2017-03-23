effect module EventEmitter
    where { command = MyCmd }
    exposing
        ( listen
        , listenOnce
        , unlisten
        , trigger
        , Id
        )

{-|
    Event Emitter

@docs listen , listenOnce , unlisten, trigger , Id
-}

import Dict exposing (..)
import Task exposing (Task)


-- API


{-| EventEmitter id
-}
type alias Id =
    String


type MyCmd msg
    = Listen Id Bool (TriggerTagger msg)
    | Unlisten Id (TriggerTagger msg)
    | Trigger Id



-- Taggers


{-| Send completion tagger
-}
type alias TriggerTagger msg =
    Id -> msg


type alias ListenState msg =
    { tagger : TriggerTagger msg
    , once : Bool
    }


{-| Effects manager state
-}
type alias State msg =
    { events : Dict Id (List (ListenState msg))
    }



-- Cmds


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap f cmd =
    case cmd of
        Listen eventId once tagger ->
            Listen eventId once (f << tagger)

        Unlisten eventId tagger ->
            Unlisten eventId (f << tagger)

        Trigger eventId ->
            Trigger eventId


{-| Listen to id
-}
listen : TriggerTagger msg -> Id -> Cmd msg
listen tagger eventId =
    command (Listen eventId False tagger)


{-| Listen once to id
-}
listenOnce : TriggerTagger msg -> Id -> Cmd msg
listenOnce tagger eventId =
    command (Listen eventId True tagger)


{-| Stop listening to id
-}
unlisten : TriggerTagger msg -> Id -> Cmd msg
unlisten tagger eventId =
    command (Unlisten eventId tagger)


{-| Trigger event
-}
trigger : Id -> Cmd msg
trigger eventId =
    command (Trigger eventId)



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
    Task.succeed <| State Dict.empty



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


settings0 : Platform.Router msg (Msg msg) -> (a -> Msg msg) -> Msg msg -> { onError : a -> Task msg (), onSuccess : Never -> Task x () }
settings0 router errorTagger tagger =
    { onError = \err -> Platform.sendToSelf router (errorTagger err)
    , onSuccess = \_ -> Platform.sendToSelf router tagger
    }


settings1 : Platform.Router msg (Msg msg) -> (a -> Msg msg) -> (b -> Msg msg) -> { onError : a -> Task Never (), onSuccess : b -> Task x () }
settings1 router errorTagger tagger =
    { onError = \err -> Platform.sendToSelf router (errorTagger err)
    , onSuccess = \result1 -> Platform.sendToSelf router (tagger result1)
    }


settings2 : Platform.Router msg (Msg msg) -> (a -> Msg msg) -> (b -> c -> Msg msg) -> { onError : a -> Task Never (), onSuccess : b -> c -> Task x () }
settings2 router errorTagger tagger =
    { onError = \err -> Platform.sendToSelf router (errorTagger err)
    , onSuccess = \result1 result2 -> Platform.sendToSelf router (tagger result1 result2)
    }


handleCmd : Platform.Router msg (Msg msg) -> State msg -> MyCmd msg -> ( Task Never (), State msg )
handleCmd router state cmd =
    case cmd of
        Listen eventId once tagger ->
            let
                listenState =
                    { tagger = tagger
                    , once = once
                    }
            in
                ( Task.succeed (), { state | events = Dict.insert eventId (listenState :: (Dict.get eventId state.events ?= [])) state.events } )

        Unlisten eventId tagger ->
            Dict.get eventId state.events
                |?> (\listenStates ->
                        let
                            msg =
                                tagger ""

                            listeners =
                                listenStates
                                    |> List.filter (\listenState -> listenState.tagger "" /= msg)
                        in
                            ( Task.succeed (), { state | events = (listeners == []) ? ( Dict.remove eventId state.events, Dict.insert eventId listeners state.events ) } )
                    )
                ?= ( Task.succeed (), state )

        Trigger eventId ->
            let
                task =
                    (Dict.get eventId state.events ?= [])
                        |> List.map .tagger
                        |> List.map (\tagger -> Platform.sendToApp router (tagger eventId))
                        |> List.foldl (&>) (Task.succeed ())

                listeners =
                    (Dict.get eventId state.events ?= [])
                        |> List.filter (not << .once)
            in
                ( task, { state | events = (listeners == []) ? ( Dict.remove eventId state.events, Dict.insert eventId listeners state.events ) } )


type Msg msg
    = Nop


onSelfMsg : Platform.Router msg (Msg msg) -> Msg msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    Task.succeed state
