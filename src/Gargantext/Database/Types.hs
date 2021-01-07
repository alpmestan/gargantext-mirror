{-|
Module      : Gargantext.Database.Types
Description : Specific Types to manage core Gargantext type with database
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

-}

{-# LANGUAGE TemplateHaskell        #-}

module Gargantext.Database.Types
  where

import Gargantext.Prelude
import Gargantext.Database.Schema.Prelude
import qualified Database.PostgreSQL.Simple as PGS


-- | Index memory of any type in Gargantext
data Indexed i a =
  Indexed { _index     :: i
          , _unIndex   :: a
          }
  deriving (Show, Generic, Eq, Ord)

makeLenses ''Indexed

instance (FromField i, FromField a) => PGS.FromRow (Indexed i a) where
  fromRow = Indexed <$> field <*> field

