{-|
Module      : Gargantext.Viz.Phylo.Tools
Description : Phylomemy Tools to build/manage it
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX


-}

{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}

module Gargantext.Viz.Phylo.Aggregates.Cluster
  where

import Data.List        (head,null,tail)
import Data.Map         (Map)
import Data.Tuple       (fst)
import Gargantext.Prelude             hiding (head)
import Gargantext.Viz.Phylo
import Gargantext.Viz.Phylo.Tools
import Gargantext.Viz.Phylo.BranchMaker
import Gargantext.Viz.Phylo.Metrics.Clustering
import qualified Data.Map    as Map


-- | To apply a Clustering method to a PhyloGraph
graphToClusters :: (Clustering,[Double]) -> PhyloGraph -> [[PhyloGroup]]
graphToClusters (clust,_param) (nodes,edges) = case clust of
  Louvain           -> undefined -- louvain (nodes,edges)
  RelatedComponents -> relatedComp 0 (head nodes) (tail nodes,edges) [] []


-- | To transform a Phylo into Clusters of PhyloGroups at a given level
phyloToClusters :: Level -> (Proximity,[Double]) -> (Clustering,[Double]) -> Phylo -> Map (Date,Date) [[PhyloGroup]]
phyloToClusters lvl (prox,param) (clus,param') p = Map.fromList
                                                 $ zip (getPhyloPeriods p)
                                                       (map (\prd -> let graph = groupsToGraph (prox,param) (getGroupsWithFilters lvl prd p) p
                                                                     in if null (fst graph)
                                                                        then []
                                                                        else graphToClusters (clus,param') graph)
                                                       (getPhyloPeriods p))
