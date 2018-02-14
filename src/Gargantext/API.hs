{-|
Module      : Gargantext.Server
Description : Server API
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Main REST API of Gargantext (both Server and Client sides)

TODO/IDEA, use MOCK feature of Servant to generate fake data (for tests)
-}

{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# LANGUAGE DataKinds       #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators   #-}

module Gargantext.API
      where

import Gargantext.Prelude

import Network.Wai
import Network.Wai.Handler.Warp
import Servant
import Database.PostgreSQL.Simple (Connection, connect)
import System.IO (FilePath, print)


-- import Gargantext.API.Auth
import Gargantext.API.Node ( Roots    , roots
                           , NodeAPI  , nodeAPI
                           , NodesAPI , nodesAPI
                           )

import Gargantext.Database.Private (databaseParameters)



-- | startGargantext takes as parameters port number and Ini file.
startGargantext :: Int -> FilePath -> IO ()
startGargantext port file = do
  print ("Starting server on port " <> show port)
  param <- databaseParameters file
  conn  <- connect param
  run port ( app conn )


-- | Main routes of the API are typed
type API =  "roots"  :> Roots
       :<|> "node"   :> Capture "id" Int      :> NodeAPI
       :<|> "nodes"  :> ReqBody '[JSON] [Int] :> NodesAPI

       -- :<|> "static"   
       -- :<|> "list"     :> Capture "id" Int  :> NodeAPI
       -- :<|> "ngrams"   :> Capture "id" Int  :> NodeAPI
       -- :<|> "auth"     :> Capture "id" Int  :> NodeAPI


-- | Server declaration
server :: Connection -> Server API
server conn =  roots   conn
          :<|> nodeAPI conn
          :<|> nodesAPI conn

-- | TODO App type, the main monad in which the bot code is written with.
-- Provide config, state, logs and IO
-- type App m a =  ( MonadState AppState m
--                 , MonadReader Conf m
--                 , MonadLog (WithSeverity Doc) m
--                 , MonadIO m) => m a
-- Thanks @yannEsposito for this.
app :: Connection -> Application
app = serve api . server

api :: Proxy API
api = Proxy

