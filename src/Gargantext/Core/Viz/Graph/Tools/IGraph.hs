{-|
Module      : Gargantext.Core.Viz.Graph.Tools.IGraph
Description : Tools to build Graph
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Reference:
* Gábor Csárdi, Tamás Nepusz: The igraph software package for complex network research. InterJournal Complex Systems, 1695, 2006.

-}


module Gargantext.Core.Viz.Graph.Tools.IGraph
  where

import Data.Serialize
import Data.Singletons (SingI)
import IGraph hiding (mkGraph, neighbors, edges, nodes, Node, Graph)
import Protolude
import qualified Data.List                   as List
import qualified IGraph                      as IG
import qualified IGraph.Algorithms.Clique    as IG
import qualified IGraph.Algorithms.Community as IG
import qualified IGraph.Random               as IG

------------------------------------------------------------------
-- | Main Types
type Graph_Undirected = IG.Graph 'U () ()
type Graph_Directed   = IG.Graph 'D () ()

type Node  = IG.Node
type Graph = IG.Graph

------------------------------------------------------------------
-- | Main Graph management Functions
neighbors :: IG.Graph d v e -> IG.Node -> [IG.Node]
neighbors = IG.neighbors

edges :: IG.Graph d v e -> [Edge]
edges = IG.edges

nodes :: IG.Graph d v e -> [IG.Node]
nodes = IG.nodes

------------------------------------------------------------------
-- | Partitions
maximalCliques :: IG.Graph d v e -> [[Int]]
maximalCliques g = IG.maximalCliques g (min',max')
  where
    min' = 0
    max' = 0

------------------------------------------------------------------
type Seed = Int

-- | Tools to analyze graphs
partitions_spinglass :: (Serialize v, Serialize e)
                         => Seed -> IG.Graph 'U v e -> IO [[Int]]
partitions_spinglass s g = do
  gen <- IG.withSeed s pure
  pure $ IG.findCommunity g Nothing Nothing IG.spinglass gen

------------------------------------------------------------------

mkGraph :: (SingI d, Ord v,
             Serialize v, Serialize e) =>
     [v] -> [LEdge e] -> IG.Graph d v e
mkGraph = IG.mkGraph


------------------------------------------------------------------
mkGraphUfromEdges :: [(Int, Int)] -> Graph_Undirected
mkGraphUfromEdges es = mkGraph (List.replicate n ()) $ zip es $ repeat ()
  where
    (a,b) = List.unzip es
    n = List.length (List.nub $ a <> b)

mkGraphDfromEdges :: [(Int, Int)] -> Graph_Directed
mkGraphDfromEdges = undefined


