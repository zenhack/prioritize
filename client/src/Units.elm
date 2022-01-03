module Units exposing
    ( Conversion
    , Days
    , Hours
    , IntU
    , Milli
    , Minutes
    , Seconds
    , add
    , compose
    , daysToHours
    , div
    , fromCeil
    , fromFloor
    , fromInt
    , hoursToMinutes
    , makeConversion
    , millisToPosix
    , minutesToSeconds
    , mod
    , mul
    , posixToMillis
    , sub
    , to
    , toInt
    , toMilli
    )

{-| Module for working with quantities with units in a type-safe way.
-}

import Time


{-| An Int with units attached to it.
-}
type IntU unit
    = IntU Int


fromInt : Int -> IntU unit
fromInt =
    IntU


toInt : IntU unit -> Int
toInt (IntU n) =
    n



-- # Arithmetic


add : IntU a -> IntU a -> IntU a
add =
    binOp (+)


sub : IntU a -> IntU a -> IntU a
sub =
    binOp (-)


mul : IntU a -> IntU a -> IntU a
mul =
    binOp (*)


div : IntU a -> IntU a -> IntU a
div =
    binOp (//)


mod : IntU a -> IntU a -> IntU a
mod =
    binOp modBy


binOp : (Int -> Int -> Int) -> IntU a -> IntU a -> IntU a
binOp f x y =
    fromInt <| f (toInt x) (toInt y)



-- # Conversion between units


type Conversion a b
    = Conversion Int


to : Conversion a b -> IntU a -> IntU b
to (Conversion n) (IntU m) =
    IntU (n * m)


fromFloor : Conversion a b -> IntU b -> IntU a
fromFloor (Conversion n) m =
    fromInt <| toInt m // n


fromCeil : Conversion a b -> IntU b -> IntU a
fromCeil (Conversion n) (IntU m) =
    let
        base =
            fromFloor (Conversion n) (IntU m)
    in
    case modBy m n of
        0 ->
            base

        _ ->
            add base (fromInt 1)


{-| `makeConversion n` makes a conversion from unit `a` to unit `b`,
provided that an `a` is `n` `b`s.
-}
makeConversion : Int -> Conversion a b
makeConversion =
    Conversion


compose : Conversion a b -> Conversion b c -> Conversion a c
compose (Conversion x) (Conversion y) =
    Conversion (x * y)



-- # Common units
-- ## Time


type Seconds
    = Seconds


minutesToSeconds : Conversion Minutes Seconds
minutesToSeconds =
    makeConversion 60


type Minutes
    = Minutes


hoursToMinutes : Conversion Hours Minutes
hoursToMinutes =
    makeConversion 60


type Hours
    = Hours


daysToHours : Conversion Days Hours
daysToHours =
    makeConversion 24


type Days
    = Days



-- # SI prefixes


type Milli a
    = Milli


toMilli : Conversion a (Milli a)
toMilli =
    makeConversion 1000



-- # Integration with time package


posixToMillis : Time.Posix -> IntU (Milli Seconds)
posixToMillis =
    Time.posixToMillis >> fromInt


millisToPosix : IntU (Milli Seconds) -> Time.Posix
millisToPosix =
    toInt >> Time.millisToPosix
