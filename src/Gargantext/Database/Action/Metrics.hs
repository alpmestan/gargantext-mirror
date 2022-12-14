{-|
Module      : Gargantext.Database.Metrics
Description : Get Metrics from Storage (Database like)
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Node API
-}

module Gargantext.Database.Action.Metrics
  where

import Data.HashMap.Strict (HashMap)
import Data.Vector (Vector)
import Gargantext.API.Ngrams.Tools (filterListWithRoot, groupNodesByNgrams, Diagonal(..), getCoocByNgrams, mapTermListRoot, RootTerm, getRepo')
import Gargantext.API.Ngrams.Types (TabType(..), ngramsTypeFromTabType, NgramsTerm)
import Gargantext.Core.Text.Metrics (scored, Scored(..), {-localMetrics, toScored-})
import Gargantext.Core.Types (ListType(..), Limit, NodeType(..))
import Gargantext.Core.NodeStory
import Gargantext.Database.Action.Flow.Types (FlowCmdM)
import Gargantext.Database.Action.Metrics.NgramsByNode (getNodesByNgramsOnlyUser{-, getTficfWith-})
import Gargantext.Database.Admin.Config (userMaster)
import Gargantext.Database.Admin.Types.Node (ListId, CorpusId)
import Gargantext.Database.Query.Table.Node (defaultList)
import Gargantext.Database.Query.Table.Node.Select
import Gargantext.Prelude
import qualified Data.HashMap.Strict as HM

getMetrics :: FlowCmdM env err m
            => CorpusId -> Maybe ListId -> TabType -> Maybe Limit
            -> m (HashMap NgramsTerm (ListType, Maybe NgramsTerm), Vector (Scored NgramsTerm))
getMetrics cId maybeListId tabType maybeLimit = do
  (ngs, _, myCooc) <- getNgramsCooc cId maybeListId tabType maybeLimit
  -- TODO HashMap
  pure (ngs, scored myCooc)


getNgramsCooc :: (FlowCmdM env err m)
            => CorpusId -> Maybe ListId -> TabType -> Maybe Limit
            -> m ( HashMap NgramsTerm (ListType, Maybe NgramsTerm)
                 , HashMap NgramsTerm (Maybe RootTerm)
                 , HashMap (NgramsTerm, NgramsTerm) Int
                 )
getNgramsCooc cId maybeListId tabType maybeLimit = do
  (ngs', ngs) <- getNgrams cId maybeListId tabType

  let
    take' Nothing  xs = xs
    take' (Just n) xs = take n xs

  lId  <- defaultList cId
  lIds <- selectNodesWithUsername NodeList userMaster

  myCooc <- HM.filter (>1) <$> getCoocByNgrams (Diagonal True)
                           <$> groupNodesByNgrams ngs
                           <$> getNodesByNgramsOnlyUser cId (lIds <> [lId]) (ngramsTypeFromTabType tabType)
                                                            (take' maybeLimit $ HM.keys ngs)
  pure $ (ngs', ngs, myCooc)



getNgrams :: (HasNodeStory env err m)
            => CorpusId -> Maybe ListId -> TabType
            -> m ( HashMap NgramsTerm (ListType, Maybe NgramsTerm)
                 , HashMap NgramsTerm (Maybe RootTerm)
                 )
getNgrams cId maybeListId tabType = do

  lId <- case maybeListId of
    Nothing   -> defaultList cId
    Just lId' -> pure lId'

  lists <- mapTermListRoot [lId] (ngramsTypeFromTabType tabType) <$> getRepo' [lId]
  let maybeSyn = HM.unions $ map (\t -> filterListWithRoot t lists)
                             [MapTerm, StopTerm, CandidateTerm]
  pure (lists, maybeSyn)




