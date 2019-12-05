{-|
Module      : Gargantext.API.Corpus.New
Description : New corpus API
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

New corpus means either:
- new corpus
- new data in existing corpus
-}

{-# LANGUAGE NoImplicitPrelude  #-}
{-# LANGUAGE TemplateHaskell    #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE DataKinds          #-}
{-# LANGUAGE TypeOperators      #-}
{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE RankNTypes         #-}

module Gargantext.API.Corpus.New
      where

import Data.Either
import Control.Monad.IO.Class (liftIO)
import Data.Aeson.TH (deriveJSON)
import Data.Swagger
import Data.Text (Text)
import GHC.Generics (Generic)
import Gargantext.Core.Utils.Prefix (unPrefix, unPrefixSwagger)
import Gargantext.Database.Flow (flowCorpusSearchInDatabase)
import Gargantext.Database.Types.Node (CorpusId)
import Gargantext.Text.Terms (TermType(..))
import Gargantext.Prelude
import Gargantext.API.Orchestrator.Types
import Servant
-- import Servant.Job.Server
import Test.QuickCheck (elements)
import Test.QuickCheck.Arbitrary
import Gargantext.Core (Lang(..))
import Gargantext.Database.Flow (FlowCmdM, flowCorpus)
import qualified Gargantext.Text.Corpus.API as API
import Gargantext.Database.Types.Node (UserId)

data Query = Query { query_query      :: Text
                   , query_corpus_id  :: Int
                   , query_databases  :: [API.ExternalAPIs]
                   }
                   deriving (Eq, Show, Generic)

deriveJSON (unPrefix "query_") 'Query


instance Arbitrary Query where
    arbitrary = elements [ Query q n fs
                         | q <- ["a","b"]
                         , n <- [0..10]
                         , fs <- take 3 $ repeat API.externalAPIs
                         ]

instance ToSchema Query where
  declareNamedSchema = genericDeclareNamedSchema (unPrefixSwagger "query_")

type Api = Summary "New Corpus endpoint"
         :> ReqBody '[JSON] Query
         :> Post '[JSON] CorpusId
        :<|> Get '[JSON] ApiInfo

-- | TODO manage several apis
-- TODO-ACCESS
-- TODO this is only the POST
api :: (FlowCmdM env err m) => Query -> m CorpusId
api (Query q _ as) = do
  cId <- case head as of
    Nothing      -> flowCorpusSearchInDatabase "user1" EN q
    Just API.All -> flowCorpusSearchInDatabase "user1" EN q
    Just a   -> do
      docs <- liftIO $ API.get a q (Just 1000)
      cId' <- flowCorpus "user1" (Left q) (Multi EN) [docs]
      pure cId'

  pure cId

------------------------------------------------
data ApiInfo = ApiInfo { api_info :: [API.ExternalAPIs]}
  deriving (Generic)
instance Arbitrary ApiInfo where
  arbitrary = ApiInfo <$> arbitrary

deriveJSON (unPrefix "") 'ApiInfo

instance ToSchema ApiInfo

info :: FlowCmdM env err m => UserId -> m ApiInfo
info _u = pure $ ApiInfo API.externalAPIs

{-
-- Proposal to replace the Query type which seems to generically named.
data ScraperInput = ScraperInput
  { _scin_query     :: !Text
  , _scin_corpus_id :: !Int
  , _scin_databases :: [API.ExternalAPIs]
  }
  deriving (Eq, Show, Generic)

makeLenses ''ScraperInput

deriveJSON (unPrefix "_scin_") 'ScraperInput

data ScraperEvent = ScraperEvent
  { _scev_message :: !(Maybe Text)
  , _scev_level   :: !(Maybe Text)
  , _scev_date    :: !(Maybe Text)
  }
  deriving Generic

deriveJSON (unPrefix "_scev_") 'ScraperEvent

data ScraperStatus = ScraperStatus
  { _scst_succeeded :: !(Maybe Int)
  , _scst_failed    :: !(Maybe Int)
  , _scst_remaining :: !(Maybe Int)
  , _scst_events    :: !(Maybe [ScraperEvent])
  }
  deriving Generic

deriveJSON (unPrefix "_scst_") 'ScraperStatus
-}

type API_v2 =
  Summary "Add to corpus endpoint" :>
  "corpus" :>
  Capture "corpus_id" CorpusId :>
  "add" :>
  "async" :> ScraperAPI2

  -- TODO ScraperInput2 also has a corpus id
addToCorpusJobFunction :: FlowCmdM env err m => CorpusId -> ScraperInput2 -> (ScraperStatus -> m ()) -> m ScraperStatus
addToCorpusJobFunction _cid _input logStatus = do
  -- TODO ...
  logStatus ScraperStatus { _scst_succeeded = Just 10
                          , _scst_failed    = Just 2
                          , _scst_remaining = Just 138
                          , _scst_events    = Just []
                          }
  -- TODO ...
  pure      ScraperStatus { _scst_succeeded = Just 137
                          , _scst_failed    = Just 13
                          , _scst_remaining = Just 0
                          , _scst_events    = Just []
                          }
