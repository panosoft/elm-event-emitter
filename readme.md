# Elm Event Emitter

Event emission in Elm to allow Elm programs to Listen for events and Notify when they occur.

## Install

### Elm

Since the Elm Package Manager doesn't allow for Native code and most everything we write at Panoramic Software has some native code in it,
you have to install this library directly from GitHub, e.g. via [elm-github-install](https://github.com/gdotdesign/elm-github-install) or some equivalent mechanism. It's just not worth the hassle of putting libraries into the Elm package manager until it allows native code.

## Usefulness
Currently, Elm standard subscriptions are effectively just Effects Manager events. That's great for most things, but what happens when you want to send an Event Message based on an event in your Elm code. That's what this library allows you to do.

You can subscribe to a unique event id and then the publisher can trigger that event notifying all subscribers.

# API

All API usages can best be seen in the test program, `test/Main.elm`.

## Event identification

```elm
type alias Id =
    String
```

This can be any unique string. Emphasis on ***unique***. That's because it's really easy to make a mistake with this and have name collisions especially when a shared module is used by two different parts of your program. GUIDs work well here.
Also, we've used *fully-qualified module names* with an incrementing count to produce unique ids.

But be warned both approaches are potentially fraught with errors. If you use GUIDs, make sure that the GUID generator has a Singleton Model, i.e. there's only one seed in the whole of your program. If you use the module name, make sure that it too has a Singleton Model.

## Listening

> Listen for an event specified by id send a message using the speicfied tagger.

```elm
listen : TriggerTagger msg -> Id -> Cmd msg
listen tagger eventId
```
> Stop listening to an event specified by id and tagger.

```elm
unlisten : TriggerTagger msg -> Id -> Cmd msg
unlisten tagger eventId
```

> Listen once for an event and auto unlisten.

```elm
listenOnce : TriggerTagger msg -> Id -> Cmd msg
listenOnce tagger eventId =
    command (Listen eventId True tagger)
```

## Triggering

> Trigger event

```elm
trigger : Id -> Cmd msg
trigger eventId =
    command (Trigger eventId)
```
