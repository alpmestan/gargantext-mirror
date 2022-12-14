{-|
Module      : Gargantext.Utils
Description : 
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Here is a longer description of this module, containing some
commentary with @some markup@.
-}


module Gargantext.Core.Utils ( 
                           -- module Gargantext.Utils.Chronos
                             module Gargantext.Core.Utils.Prefix
                           , something
                          ) where

import Data.Maybe
import Data.Monoid

-- import Gargantext.Utils.Chronos
import Gargantext.Core.Utils.Prefix



something :: Monoid a => Maybe a -> a
something Nothing  = mempty
something (Just a) = a
