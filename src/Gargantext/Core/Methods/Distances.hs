{-|
Module      : Gargantext.Graph.Distances
Description : Distance management tools
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

-}

{-# LANGUAGE Strict            #-}

module Gargantext.Core.Methods.Distances
  where

import Data.Aeson
import Data.Array.Accelerate (Matrix)
import Data.Swagger
import GHC.Generics (Generic)
import Gargantext.Core.Methods.Distances.Accelerate.Conditional (measureConditional)
import Gargantext.Core.Methods.Distances.Accelerate.Distributional (logDistributional)
import Gargantext.Prelude (Ord, Eq, Int, Double)
import Gargantext.Prelude (Show)
import Prelude (Enum, Bounded, minBound, maxBound)
import Test.QuickCheck (elements)
import Test.QuickCheck.Arbitrary

------------------------------------------------------------------------
data Distance = Conditional | Distributional
  deriving (Show)

measure :: Distance -> Matrix Int -> Matrix Double
measure Conditional    = measureConditional
measure Distributional = logDistributional

------------------------------------------------------------------------
withMetric :: GraphMetric -> Distance
withMetric Order1 = Conditional
withMetric Order2 = Distributional

------------------------------------------------------------------------
data GraphMetric = Order1 | Order2
    deriving (Generic, Eq, Ord, Enum, Bounded, Show)

instance FromJSON  GraphMetric
instance ToJSON    GraphMetric
instance ToSchema  GraphMetric
instance Arbitrary GraphMetric where
  arbitrary = elements [ minBound .. maxBound ]

------------------------------------------------------------------------



