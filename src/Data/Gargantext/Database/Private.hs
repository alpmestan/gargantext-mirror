{-# LANGUAGE OverloadedStrings #-}

module Data.Gargantext.Database.Private where

import qualified Database.PostgreSQL.Simple as PGS

-- TODO add a reader Monad here
infoGargandb :: PGS.ConnectInfo
infoGargandb =  PGS.ConnectInfo { PGS.connectHost = "127.0.0.1"
                               , PGS.connectPort = 5432
                               , PGS.connectUser = "gargantua"
                               , PGS.connectPassword = "C8kdcUrAQy66U"
                               , PGS.connectDatabase = "gargandb" }


