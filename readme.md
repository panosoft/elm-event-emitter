# Elm Event Emitter

Event emission in Elm to allow Elm programs to Listen for events and Notify when they occur.

## Install

### Elm

Since the Elm Package Manager doesn't allow for Native code and most everything we write at Panoramic Software has some native code in it,
you have to install this library directly from GitHub, e.g. via [elm-github-install](https://github.com/gdotdesign/elm-github-install) or some equivalent mechanism. It's just not worth the hassle of putting libraries into the Elm package manager until it allows native code.

## Usefulness

Currently, Elm standard subscriptions are effectively just Effects Manager events, which means they almost all originate in Javascript code. That's great for most things, but what happens when you want to send an Event Message based on an event in your Elm code. That's what this library allows you to do.

You can subscribe to a unique event id and then the publisher can trigger that event via it's unique id subsequently notifying all subscribers. There are 2 types, with a payload and without.

# API

All API usages can best be seen in the test program, `test/Main.elm`.

## Event Ids

```elm
type alias Id =
    String
```

This can be any unique string. Emphasis on ***unique***. That's because it's really easy to make a mistake with this and have name collisions especially when a shared module is used by two different parts of your program.
You could use GUIDs or *fully-qualified module names* with an incrementing count to produce unique ids.

But be warned both approaches are potentially fraught with errors. If you use GUIDs, make sure that the GUID generator has a Singleton Model, i.e. there's **one and only one** seed in the whole of your program. If you use the module name, make sure that it too has a Singleton Model, i.e. there is one instance of it's model.

N.B. Event Ids for [Events](#events) and [Sends](#sends) are independent, i.e. the same Event Id can be used for both without interfering with the other. See test program, `test/Main.elm` to see how the **same** ids are used for both.

## Events

You may listen to an event either continously or once. You also may stop listening to that event at any time. All information passed to the subscriber must be known ***before*** the event is triggered. To accomplish this, you should partially apply your Tagger functions (Message Constructors).

To send information ***after*** the event has occurred see [Sends](#sends).

### listen

> Listen for an event specified by id send a message using the specified tagger.

```elm
listen : TriggerTagger msg -> Id -> Cmd msg
listen tagger eventId
```
> Stop listening to an event specified by id and tagger.

### unlisten

```elm
unlisten : TriggerTagger msg -> Id -> Cmd msg
unlisten tagger eventId
```

### listenOnce

> Listen ONCE for an event and auto unlisten.

```elm
listenOnce : TriggerTagger msg -> Id -> Cmd msg
listenOnce tagger eventId =
```

### trigger

> Trigger event

```elm
trigger : Id -> Cmd msg
trigger eventId =
```

## Sends

You may receive a `String` from an event either continously or once. You also may stop receiving `Strings` from that event.

***N.B. Only `Strings` can be sent due to limitations in the `command` function signature in Effects Managers.*** A concrete type had to be choosen and `String` is by far the most flexible.

To get around this limitation, one could use JSON Encoding prior to sending and hence JSON Decoding upon receipt.

### receive

> Receive `Strings` from an event specified by id send a message using the specified tagger.

```elm
receive : SendTagger msg -> Id -> Cmd msg
receive tagger eventId
```
> Stop receiving `Strings` from an event specified by id and tagger.

### unreceive

```elm
unreceive : SendTagger msg -> Id -> Cmd msg
unreceive tagger eventId
```

### receiveOnce

> Receive a `String` ONCE for an event and auto unlisten.

```elm
receiveOnce : SendTagger msg -> Id -> Cmd msg
receiveOnce tagger eventId
```

### send

> Send `String`

```elm
send : Id -> String -> Cmd msg
send eventId payload
```
