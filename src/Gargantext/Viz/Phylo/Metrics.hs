{-|
Module      : Gargantext.Viz.Phylo.Tools
Description : Phylomemy Tools to build/manage it
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}

{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes        #-}
{-# LANGUAGE ViewPatterns      #-}

module Gargantext.Viz.Phylo.Metrics
  where

import Gargantext.Prelude

import Data.List ((\\), sortOn, concat, nub, take, union, intersect, null)
import Data.Map  (Map, foldlWithKey, toList, size, unionWith, intersection, intersectionWith, filterWithKey, elems, fromList, findWithDefault)
import Data.Text (Text)

-- import Debug.Trace (trace)

----------------
-- | Ngrams | --
----------------


-- | Return the conditional probability of i knowing j 
conditional :: Ord a => Map (a,a) Double -> a -> a -> Double
conditional m i j = (findWithDefault 0 (i,j) m) 
                  / foldlWithKey (\s (x,_) v -> if x == j 
                                                 then s + v
                                                 else s ) 0 m


-- | Return the genericity score of a given ngram
genericity :: Map (Int, Int) Double -> [Int] -> Int -> Double 
genericity m l i = ( (sum $ map (\j -> conditional m i j) l) 
                   - (sum $ map (\j -> conditional m j i) l)) / 2


-- | Return the specificity score of a given ngram
specificity :: Map (Int, Int) Double -> [Int] -> Int -> Double 
specificity m l i = ( (sum $ map (\j -> conditional m j i) l)
                    - (sum $ map (\j -> conditional m i j) l)) / 2


-- | Return the coverage score of a given ngram
coverage :: Map (Int, Int) Double -> [Int] -> Int -> Double 
coverage m l i = ( (sum $ map (\j -> conditional m j i) l)
                 + (sum $ map (\j -> conditional m i j) l)) / 2


-- | Process some metrics on top of ngrams
getNgramsMeta :: Map (Int, Int) Double -> [Int] -> Map Text [Double]
getNgramsMeta m ngrams = fromList 
    [ ("genericity" , map (\n -> genericity  m (ngrams \\ [n]) n) ngrams ),
      ("specificity", map (\n -> specificity m (ngrams \\ [n]) n) ngrams ),
      ("coverage"   , map (\n -> coverage    m (ngrams \\ [n]) n) ngrams  )]


-- | To get the nth most occurent elems in a coocurency matrix
getNthMostOcc :: Int -> Map (Int,Int) Double -> [Int]
getNthMostOcc nth cooc = (nub . concat)
                       $ map (\((idx,idx'),_) -> [idx,idx'])
                       $ take nth
                       $ reverse 
                       $ sortOn snd $ toList cooc


-------------------------
-- | Ngrams Dynamics | --
-------------------------


-------------------
-- | Proximity | --
-------------------


-- | Process the inverse sumLog
sumInvLog :: Double -> [Double] -> Double
sumInvLog s l = foldl (\mem x -> mem + (1 / log (s + x))) 0 l


-- | Process the sumLog
sumLog :: Double -> [Double] -> Double
sumLog s l = foldl (\mem x -> mem + log (s + x)) 0 l  


-- | To compute a jaccard similarity between two lists
jaccard :: [Int] -> [Int] -> Double
jaccard inter' union' = ((fromIntegral . length) $ inter') / ((fromIntegral . length) $ union')


-- | To get the diagonal of a matrix
toDiago :: Map (Int, Int) Double -> [Double]  
toDiago cooc = elems $ filterWithKey (\(x,x') _ -> x == x') cooc  


-- | To process WeighedLogJaccard distance between to coocurency matrix
weightedLogJaccard :: Double -> Double -> Map (Int, Int) Double -> Map (Int, Int) Double -> [Int] -> [Int] -> Double
weightedLogJaccard sens nbDocs cooc cooc' ngrams ngrams' 
  | null gInter      = 0
  | gInter == gUnion = 1
  | sens == 0        = jaccard gInter gUnion
  | sens > 0         = (sumInvLog sens wInter) / (sumInvLog sens wUnion)
  | otherwise        = (sumLog sens wInter) / (sumLog sens wUnion)
  where
    --------------------------------------
    gInter :: [Int] 
    gInter = intersect ngrams ngrams'   
    --------------------------------------
    gUnion :: [Int] 
    gUnion = union ngrams ngrams'
    --------------------------------------
    wInter :: [Double]
    wInter = toDiago $ map (/nbDocs) $ intersectionWith (+) cooc cooc'      
    --------------------------------------
    wUnion :: [Double]
    wUnion = toDiago $ map (/nbDocs) $ unionWith (+) cooc cooc'
    --------------------------------------


-- | To process the Hamming distance between two PhyloGroup fields 
hamming :: Map (Int, Int) Double -> Map (Int, Int) Double -> Double
hamming f1 f2 = fromIntegral $ max ((size inter) - (size f1)) ((size inter) - (size f2))
  where
    --------------------------------------
    inter :: Map (Int, Int) Double
    inter = intersection f1 f2 
    --------------------------------------






