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
{-# LANGUAGE RankNTypes        #-}

module Gargantext.Viz.Phylo.Tools
  where

import Control.Lens         hiding (both, Level)
import Data.List            (filter, intersect, (++), sort, null, head, tail, last, tails, delete, nub)
import Data.Map             (Map, mapKeys, member)
import Data.Set             (Set)
import Data.Text            (Text, toLower)
import Data.Tuple.Extra
import Data.Vector          (Vector,elemIndex)
import Gargantext.Prelude   hiding (head)
import Gargantext.Viz.Phylo

import qualified Data.Map    as Map
import qualified Data.Set    as Set
import qualified Data.Vector as Vector


------------------------------------------------------------------------
-- | Tools | --


alterGroupWithLevel :: (PhyloGroup -> PhyloGroup) -> Level -> Phylo -> Phylo
alterGroupWithLevel f lvl p = over ( phylo_periods
                                   .  traverse
                                   . phylo_periodLevels
                                   .  traverse
                                   . phylo_levelGroups
                                   .  traverse
                                   ) (\g -> if getGroupLevel g == lvl
                                            then f g
                                            else g ) p  



-- | To alter each list of PhyloGroups following a given function
alterPhyloGroups :: ([PhyloGroup] -> [PhyloGroup]) -> Phylo -> Phylo
alterPhyloGroups f p = over ( phylo_periods
                            .  traverse
                            . phylo_periodLevels
                            .  traverse
                            . phylo_levelGroups
                            ) f p   


-- | To alter each PhyloPeriod of a Phylo following a given function
alterPhyloPeriods :: (PhyloPeriod -> PhyloPeriod) -> Phylo -> Phylo
alterPhyloPeriods f p = over ( phylo_periods
                             .  traverse) f p


-- | To alter a list of PhyloLevels following a given function
alterPhyloLevels :: ([PhyloLevel] -> [PhyloLevel]) -> Phylo -> Phylo
alterPhyloLevels f p = over ( phylo_periods
                            .  traverse
                            . phylo_periodLevels) f p


-- | To append a list of PhyloPeriod to a Phylo
appendToPhyloPeriods :: [PhyloPeriod] -> Phylo -> Phylo
appendToPhyloPeriods l p = over (phylo_periods) (++ l) p


-- | Does a List of Sets contains at least one Set of an other List
doesAnySetContains :: Eq a =>  Set a -> [Set a] -> [Set a] -> Bool
doesAnySetContains h l l' = any (\c -> doesContains (Set.toList c) (Set.toList h)) (l' ++ l)


-- | Does a list of A contains an other list of A
doesContains :: Eq a => [a] -> [a] -> Bool
doesContains l l'
  | null l'               = True
  | length l' > length l  = False
  | elem (head l') l      = doesContains l (tail l')
  | otherwise             = False


-- | Does a list of ordered A contains an other list of ordered A
doesContainsOrd :: Eq a => Ord a => [a] -> [a] -> Bool
doesContainsOrd l l'
  | null l'          = False
  | last l < head l' = False
  | head l' `elem` l = True
  | otherwise        = doesContainsOrd l (tail l')


 -- | To filter the PhyloGroup of a Phylo according to a function and a value
filterGroups :: Eq a => (PhyloGroup -> a) -> a -> [PhyloGroup] -> [PhyloGroup]
filterGroups f x l = filter (\g -> (f g) == x) l


-- | To filter nested Sets of a
filterNestedSets :: Eq a => Set a -> [Set a] -> [Set a] -> [Set a]
filterNestedSets h l l'
  | null l                 = if doesAnySetContains h l l'
                             then l'
                             else h : l'
  | doesAnySetContains h l l' = filterNestedSets (head l) (tail l) l'
  | otherwise              = filterNestedSets (head l) (tail l) (h : l')


-- | To filter some PhyloEdges with a given threshold
filterPhyloEdges :: Double -> PhyloEdges -> PhyloEdges
filterPhyloEdges thr edges = filter (\((_s,_t),w) -> w > thr) edges 


-- | To get the foundations of a Phylo
getFoundations :: Phylo -> Vector Ngrams
getFoundations = _phylo_foundations


-- | To get the Index of a Ngrams in the Foundations of a Phylo
getIdxInFoundations :: Ngrams -> Phylo -> Int
getIdxInFoundations n p = case (elemIndex n (getFoundations p)) of
    Nothing  -> panic "[ERR][Viz.Phylo.Tools.getFoundationIdx] Ngrams not in Foundations"
    Just idx -> idx


-- | To get the PhyloGroups Childs of a PhyloGroup
getGroupChilds :: PhyloGroup -> Phylo -> [PhyloGroup]
getGroupChilds g p = getGroupsFromIds (map fst $ _phylo_groupPeriodChilds g) p


-- | To get the id of a PhyloGroup
getGroupId :: PhyloGroup -> PhyloGroupId
getGroupId = _phylo_groupId


-- | To get the Cooc Matrix of a PhyloGroup
getGroupCooc :: PhyloGroup -> Map (Int,Int) Double
getGroupCooc = _phylo_groupCooc


-- | To get the level out of the id of a PhyloGroup
getGroupLevel :: PhyloGroup -> Int
getGroupLevel = snd . fst . getGroupId


-- | To get the PhyloGroups Level Childs Ids of a PhyloGroup
getGroupLevelChildsId :: PhyloGroup -> [PhyloGroupId]
getGroupLevelChildsId g = map fst $ _phylo_groupLevelChilds g


-- | To get the Ngrams of a PhyloGroup
getGroupNgrams :: PhyloGroup -> [Int]
getGroupNgrams =  _phylo_groupNgrams


-- | To get the list of pairs (Childs & Parents) of a PhyloGroup
getGroupPairs :: PhyloGroup -> Phylo -> [PhyloGroup]
getGroupPairs g p = (getGroupChilds g p) ++ (getGroupParents g p)


-- | To get the PhyloGroups Parents of a PhyloGroup
getGroupParents :: PhyloGroup -> Phylo -> [PhyloGroup]
getGroupParents g p = getGroupsFromIds (map fst $ _phylo_groupPeriodParents g) p


-- | To get the period out of the id of a PhyloGroup
getGroupPeriod :: PhyloGroup -> (Date,Date)
getGroupPeriod = fst . fst . getGroupId


-- | To get all the PhyloGroup of a Phylo
getGroups :: Phylo -> [PhyloGroup]
getGroups = view ( phylo_periods
                 .  traverse
                 . phylo_periodLevels
                 .  traverse 
                 . phylo_levelGroups
                 )


-- | To all PhyloGroups matching a list of PhyloGroupIds in a Phylo
getGroupsFromIds :: [PhyloGroupId] -> Phylo -> [PhyloGroup]
getGroupsFromIds ids p = filter (\g -> elem (getGroupId g) ids) $ getGroups p


-- | To get all the PhyloGroup of a Phylo with a given level and period
getGroupsWithFilters :: Int -> (Date,Date) -> Phylo -> [PhyloGroup]
getGroupsWithFilters lvl prd p = (getGroupsWithLevel  lvl p)
                                 `intersect`
                                 (getGroupsWithPeriod prd p)


-- | To get all the PhyloGroup of a Phylo with a given Level
getGroupsWithLevel :: Int -> Phylo -> [PhyloGroup]
getGroupsWithLevel lvl p = filterGroups getGroupLevel lvl (getGroups p)


-- | To get all the PhyloGroup of a Phylo with a given Period
getGroupsWithPeriod :: (Date,Date) -> Phylo -> [PhyloGroup]
getGroupsWithPeriod prd p = filterGroups getGroupPeriod prd (getGroups p)
              

-- | To get the good pair of keys (x,y) or (y,x) in a given Map (a,b) c
getKeyPair :: (Int,Int) -> Map (Int,Int) a -> (Int,Int)
getKeyPair (x,y) m = case findPair (x,y) m of
                      Nothing -> panic "[ERR][Viz.Phylo.Example.getKeyPair] Nothing"
                      Just i  -> i
                     where
                      --------------------------------------
                      findPair :: (Int,Int) -> Map (Int,Int) a -> Maybe (Int,Int)
                      findPair (x',y') m'
                        | member (x',y') m' = Just (x',y')
                        | member (y',x') m' = Just (y',x')
                        | otherwise      = Nothing
                      --------------------------------------


-- | To get the last computed Level in a Phylo
getLastLevel :: Phylo -> Level 
getLastLevel p = (last . sort) 
               $ map (snd . getPhyloLevelId) 
               $ view ( phylo_periods
                      .  traverse
                      . phylo_periodLevels ) p


-- | To get the neighbours (directed/undirected) of a PhyloGroup from a list of PhyloEdges 
getNeighbours :: Bool -> PhyloGroup -> PhyloEdges -> [PhyloGroup]
getNeighbours directed g e = case directed of 
  True  -> map (\((_s,t),_w) -> t) 
             $ filter (\((s,_t),_w) -> s == g) e 
  False -> map (\((s,t),_w) -> head $ delete g $ nub [s,t,g]) 
             $ filter (\((s,t),_w) -> s == g || t == g) e


-- | To get the Branches of a Phylo
-- getPhyloBranches :: Phylo -> [PhyloBranch] 
-- getPhyloBranches = _phylo_branches


-- | To get the PhylolevelId of a given PhyloLevel
getPhyloLevelId :: PhyloLevel -> PhyloLevelId
getPhyloLevelId = _phylo_levelId


-- | To get all the Phylolevels of a given PhyloPeriod
getPhyloLevels :: PhyloPeriod -> [PhyloLevel]
getPhyloLevels = view (phylo_periodLevels)


-- | To get all the PhyloPeriodIds of a Phylo
getPhyloPeriods :: Phylo -> [PhyloPeriodId]
getPhyloPeriods p = map _phylo_periodId 
                  $ view (phylo_periods) p


-- | To get the id of a given PhyloPeriod
getPhyloPeriodId :: PhyloPeriod -> PhyloPeriodId
getPhyloPeriodId prd = _phylo_periodId prd 


-- | To init the foundation of the Phylo as a Vector of Ngrams 
initFoundations :: [Ngrams] -> Vector Ngrams
initFoundations l = Vector.fromList $ map toLower l


-- | To create a PhyloGroup in a Phylo out of a list of Ngrams and a set of parameters 
initGroup :: [Ngrams] -> Text -> Int -> Int -> Int -> Int -> Phylo -> PhyloGroup
initGroup ngrams lbl idx lvl from' to' p = PhyloGroup 
  (((from', to'), lvl), idx)
  lbl
  (sort $ map (\x -> getIdxInFoundations x p) ngrams)
  (Map.empty)
  (Map.empty)
  Nothing
  [] [] [] []


-- | To init the Base of a Phylo from a List of Periods and Foundations
initPhyloBase :: [(Date, Date)] -> Vector Ngrams -> Phylo
initPhyloBase pds fds = Phylo ((fst . head) pds, (snd . last) pds) fds (map (\pd -> initPhyloPeriod pd []) pds)


-- | To create a PhyloLevel
initPhyloLevel :: PhyloLevelId -> [PhyloGroup] -> PhyloLevel
initPhyloLevel id groups = PhyloLevel id groups

-- | To create a PhyloPeriod
initPhyloPeriod :: PhyloPeriodId -> [PhyloLevel] -> PhyloPeriod
initPhyloPeriod id l = PhyloPeriod id l


-- | To filter Fis with small Support but by keeping non empty Periods
keepFilled :: (Int -> [a] -> [a]) -> Int -> [a] -> [a] 
keepFilled f thr l = if (null $ f thr l) && (not $ null l)
                     then keepFilled f (thr - 1) l
                     else f thr l  


-- | To get all combinations of a list
listToDirectedCombi :: Eq a => [a] -> [(a,a)]
listToDirectedCombi l = [(x,y) | x <- l, y <- l, x /= y]


-- | To get all combinations of a list and apply a function to the resulting list of pairs
listToDirectedCombiWith :: Eq a => forall b. (a -> b) -> [a] -> [(b,b)]
listToDirectedCombiWith f l = [(f x,f y) | x <- l, y <- l, x /= y]


-- | To get all combinations of a list with no repetition
listToUnDirectedCombi :: [a] -> [(a,a)]
listToUnDirectedCombi l = [ (x,y) | (x:rest) <- tails l,  y <- rest ]


-- | To get all combinations of a list with no repetition and apply a function to the resulting list of pairs
listToUnDirectedCombiWith :: forall a b. (a -> b) -> [a] -> [(b,b)]
listToUnDirectedCombiWith f l = [ (f x, f y) | (x:rest) <- tails l,  y <- rest ]


-- | To set the LevelId of a PhyloLevel and of all its PhyloGroups
setPhyloLevelId :: Int -> PhyloLevel -> PhyloLevel
setPhyloLevelId lvl (PhyloLevel (id, _lvl) groups)
    = PhyloLevel (id, lvl) groups'
        where 
            groups' = over (traverse . phylo_groupId) (\((period, _lvl), idx) -> ((period, lvl), idx)) groups 


-- | To unify the keys (x,y) that Map 1 share with Map 2 such as: (x,y) <=> (y,x)
unifySharedKeys :: Eq a => Ord a => Map (a,a) b -> Map (a,a) b -> Map (a,a) b
unifySharedKeys m1 m2 = mapKeys (\(x,y) -> if member (y,x) m2
                                           then (y,x)
                                           else (x,y) ) m1 
