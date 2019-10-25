{-|
Module      : Gargantext.Viz.Phylo.SynchronicClustering
Description : Module dedicated to the adaptative synchronic clustering of a Phylo.
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}

{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Gargantext.Viz.Phylo.SynchronicClustering where

import Gargantext.Prelude
import Gargantext.Viz.AdaptativePhylo
import Gargantext.Viz.Phylo.PhyloTools
import Gargantext.Viz.Phylo.TemporalMatching (weightedLogJaccard)

import Data.List ((++), null, intersect, nub, concat, sort, sortOn)
import Data.Map (Map, fromList, fromListWith, foldlWithKey, (!), insert, empty, restrictKeys, elems, mapWithKey, member)

import Control.Lens hiding (Level)
import Control.Parallel.Strategies (parList, rdeepseq, using)

import qualified Data.Map as Map


-------------------------
-- | New Level Maker | --
-------------------------

toBranchId :: PhyloGroup -> PhyloBranchId
toBranchId child = ((child ^. phylo_groupLevel) + 1, snd (child ^. phylo_groupBranchId))

mergeGroups :: [Cooc] -> PhyloGroupId -> Map PhyloGroupId PhyloGroupId -> [PhyloGroup] -> PhyloGroup
mergeGroups coocs id mapIds childs = 
    let ngrams = (sort . nub . concat) $ map _phylo_groupNgrams childs
    in PhyloGroup (fst $ fst id) (snd $ fst id) (snd id)  ""
                  (sum $ map _phylo_groupSupport childs)  ngrams
                  (ngramsToCooc ngrams coocs) (toBranchId (head' "mergeGroups" childs))
                  empty [] (map (\g -> (getGroupId g, 1)) childs)
                  (updatePointers $ concat $ map _phylo_groupPeriodParents childs)
                  (updatePointers $ concat $ map _phylo_groupPeriodChilds  childs)
    where 
        updatePointers :: [Pointer] -> [Pointer]
        updatePointers pointers = map (\(pId,w) -> (mapIds ! pId,w)) pointers


addPhyloLevel :: Level -> Phylo -> Phylo
addPhyloLevel lvl phylo = 
  over ( phylo_periods .  traverse ) 
       (\phyloPrd -> phyloPrd & phylo_periodLevels 
                        %~ (insert (phyloPrd ^. phylo_periodPeriod, lvl) (PhyloLevel (phyloPrd ^. phylo_periodPeriod) lvl empty))) phylo


toNextLevel :: Phylo -> [PhyloGroup] -> Phylo
toNextLevel phylo groups = 
    let curLvl = getLastLevel phylo
        oldGroups = fromList $ map (\g -> (getGroupId g, getLevelParentId g)) groups
        newGroups = fromListWith (++)
                  -- | 5) group the parents by periods
                  $ foldlWithKey (\acc id groups' ->
                        -- | 4) create the parent group
                        let parent = mergeGroups (elems $ restrictKeys (phylo ^. phylo_timeCooc) $ periodsToYears [(fst . fst) id]) id oldGroups groups'
                        in  acc ++ [(parent ^. phylo_groupPeriod, [parent])]) []
                  -- | 3) group the current groups by parentId
                  $ fromListWith (++) $ map (\g -> (getLevelParentId g, [g])) groups
    in  traceSynchronyEnd 
      $ over ( phylo_periods . traverse . phylo_periodLevels . traverse
             -- | 6) update each period at curLvl + 1
             . filtered (\phyloLvl -> phyloLvl ^. phylo_levelLevel == (curLvl + 1)))
             -- | 7) by adding the parents
             (\phyloLvl -> 
                if member (phyloLvl ^. phylo_levelPeriod) newGroups
                    then phyloLvl & phylo_levelGroups
                            .~ fromList (map (\g -> (getGroupId g, g)) $ newGroups ! (phyloLvl ^. phylo_levelPeriod))
                    else phyloLvl)
      -- | 2) add the curLvl + 1 phyloLevel to the phylo
      $ addPhyloLevel (curLvl + 1)
      -- | 1) update the current groups (with level parent pointers) in the phylo
      $ updatePhyloGroups curLvl (fromList $ map (\g -> (getGroupId g, g)) groups) phylo 


--------------------
-- | Clustering | --
--------------------


toPairs :: [PhyloGroup] -> [(PhyloGroup,PhyloGroup)]
toPairs groups = filter (\(g,g') -> (not . null) $ intersect (g ^. phylo_groupNgrams) (g' ^. phylo_groupNgrams))
               $ listToCombi' groups


toDiamonds :: [PhyloGroup] -> [[PhyloGroup]]
toDiamonds groups = foldl' (\acc groups' ->
                        acc ++ ( elems
                               $ Map.filter (\v -> length v > 1)
                               $ fromListWith (++)
                               $ foldl' (\acc' g -> 
                                    acc' ++ (map (\(id,_) -> (id,[g]) ) $ g ^. phylo_groupPeriodChilds)) [] groups')) []
                  $ elems
                  $ Map.filter (\v -> length v > 1)
                  $ fromListWith (++)
                  $ foldl' (\acc g -> acc ++ (map (\(id,_) -> (id,[g]) ) $ g ^. phylo_groupPeriodParents)  ) [] groups


groupsToEdges :: Proximity -> Synchrony -> Double -> [PhyloGroup] -> [((PhyloGroup,PhyloGroup),Double)]
groupsToEdges prox sync docs groups =
    case sync of
        ByProximityThreshold  t s  -> filter (\(_,w) -> w >= t)
                                    $ toEdges s
                                    $ toPairs groups
                   
        ByProximityDistribution s  -> 
            let diamonds = sortOn snd 
                         $ toEdges s $ concat
                         $ map toPairs $ toDiamonds groups 
             in take (div (length diamonds) 2) diamonds
    where 
        toEdges :: Double -> [(PhyloGroup,PhyloGroup)] -> [((PhyloGroup,PhyloGroup),Double)]
        toEdges sens edges = 
            case prox of
                WeightedLogJaccard _ _ _ -> map (\(g,g') -> 
                                                 ((g,g'), weightedLogJaccard sens docs 
                                                              (g ^. phylo_groupCooc)   (g' ^. phylo_groupCooc)
                                                              (g ^. phylo_groupNgrams) (g' ^. phylo_groupNgrams))) edges
                _ -> undefined  



toRelatedComponents :: [PhyloGroup] -> [((PhyloGroup,PhyloGroup),Double)] -> [[PhyloGroup]]
toRelatedComponents nodes edges = 
  let ref = fromList $ map (\g -> (getGroupId g, g)) nodes
      clusters = relatedComponents $ ((map (\((g,g'),_) -> [getGroupId g, getGroupId g']) edges) ++ (map (\g -> [getGroupId g]) nodes)) 
   in map (\cluster -> map (\gId -> ref ! gId) cluster) clusters 

toParentId :: PhyloGroup -> PhyloGroupId
toParentId child = ((child ^. phylo_groupPeriod, child ^. phylo_groupLevel + 1), child ^. phylo_groupIndex) 


reduceBranch :: Proximity -> Synchrony -> Map Date Double -> [PhyloGroup] -> [PhyloGroup]
reduceBranch prox sync docs branch = 
    -- | 1) reduce a branch as a set of periods & groups
    let periods = fromListWith (++)
                 $ map (\g -> (g ^. phylo_groupPeriod,[g])) branch
    in  (concat . concat . elems)
      $ mapWithKey (\prd groups -> 
            -- | 2) for each period, transform the groups as a proximity graph filtered by a threshold
            let edges = groupsToEdges prox sync ((sum . elems) $ restrictKeys docs $ periodsToYears [prd]) groups
             in map (\comp -> 
                    -- | 4) add to each groups their futur level parent group
                    let parentId = toParentId (head' "parentId" comp)
                    in  map (\g -> g & phylo_groupLevelParents %~ (++ [(parentId,1)]) ) comp )
                -- |3) reduce the graph a a set of related components
              $ toRelatedComponents groups edges) periods       


synchronicClustering :: Phylo -> Phylo
synchronicClustering phylo =
    let prox = phyloProximity $ getConfig phylo
        sync = phyloSynchrony $ getConfig phylo
        docs = phylo ^. phylo_timeDocs
        branches  = map (\branch -> reduceBranch prox sync docs branch)
                  $ phyloToLastBranches 
                  $ traceSynchronyStart phylo
        branches' = branches `using` parList rdeepseq
     in toNextLevel phylo $ concat branches'


----------------
-- | probes | --
----------------

-- synchronicDistance :: Phylo -> Level -> String
-- synchronicDistance phylo lvl = 
--     foldl' (\acc branch -> 
--              acc <> (foldl' (\acc' period ->
--                               acc' <> let prox  = phyloProximity $ getConfig phylo
--                                           sync  = phyloSynchrony $ getConfig phylo
--                                           docs  = _phylo_timeDocs phylo
--                                           prd   = _phylo_groupPeriod $ head' "distance" period
--                                           edges = groupsToEdges prox 0.1 (_bpt_sensibility sync) 
--                                                   ((sum . elems) $ restrictKeys docs $ periodsToYears [_phylo_groupPeriod $ head' "distance" period]) period
--                                       in foldl' (\mem (_,w) -> 
--                                           mem <> show (prd)
--                                               <> "\t"
--                                               <> show (w)
--                                               <> "\n"
--                                         ) "" edges 
--                      ) ""  $ elems $ groupByField _phylo_groupPeriod branch)
--     ) "period\tdistance\n" $ elems $ groupByField _phylo_groupBranchId $ getGroupsFromLevel lvl phylo