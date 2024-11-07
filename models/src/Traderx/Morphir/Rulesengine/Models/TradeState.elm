module Traderx.Morphir.Rulesengine.Models.TradeState exposing (..)


type TradeState
    = New
    | Processing -- Queued
    | Settled
    | Cancelled
