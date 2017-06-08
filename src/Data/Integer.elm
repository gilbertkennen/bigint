module Data.Integer
    exposing
        ( Integer
        , Sign(Positive, Negative)
        , sign
        , max_digit_value
        , fromInt
        , fromString
        , toString
        , add
        , sub
        , negate
        , mul
        , divmod
        , unsafeDivmod
        , abs
        , compare
        , gt
        , gte
        , lt
        , lte
        , eq
        , neq
        , max
        , min
        , zero
        , one
        , minusOne
        )

{-| Infinite digits integers
# The datatype
@docs Integer, Sign

# From/To
@docs fromInt, fromString, toString

# Common operations
@docs add, sub, negate, mul, divmod, unsafeDivmod, abs, sign

# Comparison
@docs compare, gt, gte, lt, lte, eq, neq, max, min

# Common numbers
@docs zero, one, minusOne

# Internals
@docs max_digit_value

-}

import Basics
import Char
import Debug
import List.Extra
import Maybe exposing (Maybe)
import Maybe.Extra
import Result exposing (Result)
import String


{-| The sign of the integer
-}
type Sign
    = Positive
    | Negative


type alias Digit =
    Int



{- From smallest to largest digit, all the digits are positive, no leading zeros -}


type Magnitude
    = Magnitude (List Digit)


type MagnitudeNotNormalised
    = MagnitudeNotNormalised (List Digit)


{-| Integer type
-}
type Integer
    = Integer ( Sign, Magnitude )


type IntegerNotNormalised
    = IntegerNotNormalised ( Sign, MagnitudeNotNormalised )


{-| Enough to hold digit * digit without overflowing to double
-}
max_digit_value : Int
max_digit_value =
    1000000


{-| Makes an Integer from an Int
-}
fromInt : Int -> Integer
fromInt x =
    let
        sign =
            if x < 0 then
                Negative
            else
                Positive
    in
        normalise <| IntegerNotNormalised ( sign, MagnitudeNotNormalised [ Basics.abs x ] )


{-| Makes an Integer from a String
-}
fromString : String -> Maybe Integer
fromString x =
    case String.toList x of
        [] ->
            Just (fromInt 0)

        '-' :: xs ->
            fromStringPrime xs
                |> Maybe.map (Integer << (,) Negative)

        '+' :: xs ->
            fromStringPrime xs
                |> Maybe.map (Integer << (,) Positive)

        xs ->
            fromStringPrime xs
                |> Maybe.map (Integer << (,) Positive)


fromStringPrime : List Char -> Maybe Magnitude
fromStringPrime x =
    if not <| List.all Char.isDigit x then
        Nothing
    else
        List.reverse x
            |> List.Extra.greedyGroupsOf 6
            |> List.map (List.reverse >> String.fromList >> String.toInt >> Result.toMaybe)
            |> Maybe.Extra.combine
            |> Maybe.map Magnitude


type MagnitudePair
    = MagnitudePair (List ( Digit, Digit ))


sameSizeNormalized : Magnitude -> Magnitude -> MagnitudePair
sameSizeNormalized (Magnitude xs) (Magnitude ys) =
    MagnitudePair (sameSizeRaw xs ys)


sameSizeNotNormalized : MagnitudeNotNormalised -> MagnitudeNotNormalised -> MagnitudePair
sameSizeNotNormalized (MagnitudeNotNormalised xs) (MagnitudeNotNormalised ys) =
    MagnitudePair (sameSizeRaw xs ys)


sameSizeRaw : List Int -> List Int -> List ( Int, Int )
sameSizeRaw =
    greedyZip (\x y -> ( Maybe.withDefault 0 x, Maybe.withDefault 0 y ))


greedyZip : (Maybe a -> Maybe b -> c) -> List a -> List b -> List c
greedyZip f =
    let
        go acc lefts rights =
            case ( lefts, rights ) of
                ( [], [] ) ->
                    List.reverse acc

                ( x :: xs, [] ) ->
                    go (f (Just x) Nothing :: acc) xs []

                ( [], y :: ys ) ->
                    go (f Nothing (Just y) :: acc) [] ys

                ( x :: xs, y :: ys ) ->
                    go (f (Just x) (Just y) :: acc) xs ys
    in
        go []


normalise : IntegerNotNormalised -> Integer
normalise (IntegerNotNormalised ( sign, x )) =
    let
        nmagnitude =
            normaliseMagnitude x
    in
        if isNegativeMagnitude nmagnitude then
            normalise (IntegerNotNormalised ( signNegate sign, reverseMagnitude nmagnitude ))
        else
            Integer ( sign, nmagnitude )


reverseMagnitude : Magnitude -> MagnitudeNotNormalised
reverseMagnitude (Magnitude xs) =
    MagnitudeNotNormalised (List.map ((*) -1) xs)


isNegativeMagnitude : Magnitude -> Bool
isNegativeMagnitude (Magnitude xs) =
    case List.Extra.last xs of
        Nothing ->
            False

        Just x ->
            x < 0


signNegate : Sign -> Sign
signNegate sign =
    case sign of
        Positive ->
            Negative

        Negative ->
            Positive


normaliseDigit : Int -> ( Int, Digit )
normaliseDigit d =
    if d < 0 then
        let
            ( carry, dPrime ) =
                normaliseDigit (d + max_digit_value)
        in
            ( carry - 1, dPrime )
    else
        ( d // max_digit_value, rem d max_digit_value )


normaliseDigitList : List Int -> List Digit
normaliseDigitList x =
    case x of
        [] ->
            []

        d :: [] ->
            let
                ( c, dPrime ) =
                    normaliseDigit d
            in
                [ dPrime, c ]

        d :: d2 :: xs ->
            let
                ( c, dPrime ) =
                    normaliseDigit d
            in
                dPrime :: normaliseDigitList (d2 + c :: xs)


dropZeroes : List Digit -> List Digit
dropZeroes =
    List.reverse
        >> List.Extra.dropWhile ((==) 0)
        >> List.reverse


normaliseMagnitude : MagnitudeNotNormalised -> Magnitude
normaliseMagnitude (MagnitudeNotNormalised x) =
    Magnitude (x |> normaliseDigitList |> dropZeroes)


toPositiveSign : Integer -> IntegerNotNormalised
toPositiveSign (Integer ( s, Magnitude m )) =
    let
        reverseMagnitude (Magnitude xs) =
            MagnitudeNotNormalised (List.map (\x -> -x) xs)
    in
        case s of
            Positive ->
                IntegerNotNormalised ( s, MagnitudeNotNormalised m )

            Negative ->
                IntegerNotNormalised ( Positive, reverseMagnitude (Magnitude m) )


{-| Adds two Integers
-}
add : Integer -> Integer -> Integer
add a b =
    let
        (IntegerNotNormalised ( _, ma )) =
            toPositiveSign a

        (IntegerNotNormalised ( _, mb )) =
            toPositiveSign b

        (MagnitudePair p) =
            sameSizeNotNormalized ma mb

        added =
            List.map (\( x, y ) -> x + y) p
    in
        normalise (IntegerNotNormalised ( Positive, MagnitudeNotNormalised added ))


{-| Changes the sign of an Integer
-}
negate : Integer -> Integer
negate (Integer ( s, m )) =
    let
        newsign =
            case s of
                Positive ->
                    Negative

                Negative ->
                    Positive
    in
        normalise (toPositiveSign (Integer ( newsign, m )))


{-| Absolute value
-}
abs : Integer -> Integer
abs (Integer ( s, m )) =
    Integer ( Positive, m )


{-| Substracts the second Integer from the first
-}
sub : Integer -> Integer -> Integer
sub a b =
    add a (negate b)


{-| Multiplies two Integers
-}
mul : Integer -> Integer -> Integer
mul (Integer ( s1, m1 )) (Integer ( s2, m2 )) =
    let
        sign =
            case ( s1, s2 ) of
                ( Positive, Positive ) ->
                    Positive

                ( Negative, Negative ) ->
                    Positive

                _ ->
                    Negative
    in
        Integer ( sign, (mul_magnitudes m1 m2) )


mul_magnitudes : Magnitude -> Magnitude -> Magnitude
mul_magnitudes (Magnitude m1) (Magnitude m2) =
    case m1 of
        [] ->
            Magnitude []

        [ m ] ->
            mul_single_digit (Magnitude m2) m

        m :: mx ->
            let
                accum =
                    mul_single_digit (Magnitude m2) m

                (Magnitude rest) =
                    mul_magnitudes (Magnitude mx) (Magnitude m2)

                i1 =
                    (Integer ( Positive, accum ))

                i2 =
                    (Integer ( Positive, (Magnitude (0 :: rest)) ))

                (Integer ( _, result )) =
                    add i1 i2
            in
                result


mul_single_digit : Magnitude -> Digit -> Magnitude
mul_single_digit (Magnitude m) d =
    normaliseMagnitude (MagnitudeNotNormalised (List.map (\x -> d * x) m))


{-| Compares two Integers
-}
compare : Integer -> Integer -> Order
compare (Integer ( sa, a )) (Integer ( sb, b )) =
    let
        invert_order x =
            case x of
                LT ->
                    GT

                EQ ->
                    EQ

                GT ->
                    LT
    in
        case ( sa, sb ) of
            ( Positive, Negative ) ->
                GT

            ( Negative, Positive ) ->
                LT

            _ ->
                let
                    ss =
                        sameSizeNormalized a b

                    rss =
                        reverseMagnitudePair ss

                    cr =
                        compareMagnitude rss
                in
                    if sa == Positive then
                        cr
                    else
                        invert_order cr


{-| Equals
-}
eq : Integer -> Integer -> Bool
eq a b =
    case compare a b of
        EQ ->
            True

        _ ->
            False


{-| Not equals
-}
neq : Integer -> Integer -> Bool
neq a b =
    not (eq a b)


{-| Less than
-}
lt : Integer -> Integer -> Bool
lt a b =
    case compare a b of
        LT ->
            True

        _ ->
            False


{-| Greater than
-}
gt : Integer -> Integer -> Bool
gt a b =
    case compare a b of
        GT ->
            True

        _ ->
            False


{-| Greater than or equals
-}
gte : Integer -> Integer -> Bool
gte a b =
    case compare a b of
        GT ->
            True

        EQ ->
            True

        _ ->
            False


{-| Less than or equals
-}
lte : Integer -> Integer -> Bool
lte a b =
    case compare a b of
        LT ->
            True

        EQ ->
            True

        _ ->
            False


{-| Returns the largest of two Integers
-}
max : Integer -> Integer -> Integer
max a b =
    case compare a b of
        GT ->
            a

        EQ ->
            a

        LT ->
            b


{-| Returns the smallest of two Integers
-}
min : Integer -> Integer -> Integer
min a b =
    case compare a b of
        LT ->
            a

        EQ ->
            a

        GT ->
            b


type MagnitudePairReverseOrder
    = MagnitudePairReverseOrder (List ( Digit, Digit ))


reverseMagnitudePair : MagnitudePair -> MagnitudePairReverseOrder
reverseMagnitudePair (MagnitudePair x) =
    MagnitudePairReverseOrder <| List.reverse x


compareMagnitude : MagnitudePairReverseOrder -> Order
compareMagnitude (MagnitudePairReverseOrder m) =
    case m of
        [] ->
            EQ

        ( a, b ) :: xs ->
            if a == b then
                compareMagnitude (MagnitudePairReverseOrder xs)
            else
                Basics.compare a b


zeroes : Int -> String
zeroes n =
    String.repeat n "0"


fillZeroes : Digit -> String
fillZeroes d =
    let
        d_s =
            Basics.toString d
    in
        let
            len =
                String.length d_s
        in
            zeroes (6 - len) ++ d_s


revmagnitudeToString : List Digit -> String
revmagnitudeToString m =
    case m of
        [] ->
            "0"

        [ x ] ->
            Basics.toString x

        x :: xs ->
            (Basics.toString x) ++ String.concat (List.map fillZeroes xs)


{-| Converts the Integer to a String
-}
toString : Integer -> String
toString (Integer ( s, Magnitude m )) =
    let
        sign =
            if s == Positive then
                ""
            else
                "-"
    in
        sign ++ revmagnitudeToString (List.reverse m)


range : Int -> Int -> List Int
range a b =
    if a == b then
        [ a ]
    else
        a :: range (a + 1) b


dividers : List Integer
dividers =
    let
        log =
            Basics.logBase 2 (Basics.toFloat max_digit_value)

        log_i =
            (Basics.truncate log) + 1

        exp_values =
            List.reverse (range 0 log_i)

        int_values =
            List.map (\x -> 2 ^ x) exp_values
    in
        List.map fromInt int_values


pad_digits : Int -> Integer
pad_digits n =
    if n == 0 then
        fromInt 1
    else
        mul (pad_digits (n - 1)) (fromInt max_digit_value)


divmod_digit : Integer -> List Integer -> Integer -> Integer -> ( Integer, Integer )
divmod_digit padding to_test a b =
    case to_test of
        [] ->
            ( fromInt 0, a )

        x :: xs ->
            let
                candidate =
                    mul (mul x b) padding

                ( newdiv, newmod ) =
                    if lte candidate a then
                        ( mul x padding, sub a candidate )
                    else
                        ( fromInt 0, a )

                ( restdiv, restmod ) =
                    divmod_digit padding xs newmod b
            in
                ( add newdiv restdiv, restmod )


divmodPrime : Int -> Integer -> Integer -> ( Integer, Integer )
divmodPrime n a b =
    if n == 0 then
        divmod_digit (pad_digits n) dividers a b
    else
        let
            ( cdiv, cmod ) =
                divmod_digit (pad_digits n) dividers a b

            ( rdiv, rmod ) =
                divmodPrime (n - 1) cmod b
        in
            ( add cdiv rdiv, rmod )


{-| Division and modulus
-}
divmod : Integer -> Integer -> Maybe ( Integer, Integer )
divmod a b =
    if eq b zero then
        Nothing
    else
        let
            (Integer ( s1, Magnitude m1 )) =
                a

            (Integer ( s2, Magnitude m2 )) =
                b

            cand_l =
                (List.length m1) - (List.length m2) + 1

            l =
                if cand_l < 0 then
                    0
                else
                    cand_l

            sign =
                case ( s1, s2 ) of
                    ( Positive, Positive ) ->
                        Positive

                    ( Negative, Negative ) ->
                        Positive

                    _ ->
                        Negative

            ( Integer ( _, d ), Integer ( _, m ) ) =
                divmodPrime l (abs a) (abs b)
        in
            Just ( Integer ( sign, d ), Integer ( s1, m ) )


{-| divmod that returns the pair of values, or crashes if the divisor is zero
-}
unsafeDivmod : Integer -> Integer -> ( Integer, Integer )
unsafeDivmod a b =
    let
        v =
            divmod a b
    in
        case v of
            Just r ->
                r

            Nothing ->
                Debug.crash "Divide by zero"


{-| Get the sign of the integer
-}
sign : Integer -> Sign
sign (Integer ( x, _ )) =
    x


{-| Number 0
-}
zero : Integer
zero =
    fromInt 0


{-| Number 1
-}
one : Integer
one =
    fromInt 1


{-| Number -1
-}
minusOne : Integer
minusOne =
    fromInt -1
