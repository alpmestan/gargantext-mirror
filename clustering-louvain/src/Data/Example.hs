module Data.Example where

import Data.List (sort)
import Data.Utils
import Data.Graph.Inductive


karate :: Gr () Double
-- karate =  mkGraph' <$> importGraphFromGexf "src/Data/karate.gexf"
karate = mkGraph [(1,()),(2,()),(3,()),(4,()),(5,()),(6,()),(7,()),(8,()),(9,()),(10,()),(11,()),(12,()),(13,()),(14,()),(15,()),(16,()),(17,()),(18,()),(19,()),(20,()),(21,()),(22,()),(23,()),(24,()),(25,()),(26,()),(27,()),(28,()),(29,()),(30,()),(31,()),(32,()),(33,()),(34,())] [(1,2,1.0),(1,3,1.0),(1,4,1.0),(1,5,1.0),(1,6,1.0),(1,7,1.0),(1,8,1.0),(1,9,1.0),(1,11,1.0),(1,12,1.0),(1,13,1.0),(1,14,1.0),(1,18,1.0),(1,20,1.0),(1,22,1.0),(1,32,1.0),(2,3,1.0),(2,4,1.0),(2,8,1.0),(2,14,1.0),(2,18,1.0),(2,20,1.0),(2,22,1.0),(2,31,1.0),(3,4,1.0),(3,8,1.0),(3,9,1.0),(3,10,1.0),(3,14,1.0),(3,28,1.0),(3,29,1.0),(3,33,1.0),(4,8,1.0),(4,13,1.0),(4,14,1.0),(5,7,1.0),(5,11,1.0),(6,7,1.0),(6,11,1.0),(6,17,1.0),(7,17,1.0),(9,31,1.0),(9,33,1.0),(9,34,1.0),(10,34,1.0),(14,34,1.0),(15,33,1.0),(15,34,1.0),(16,33,1.0),(16,34,1.0),(19,33,1.0),(19,34,1.0),(20,34,1.0),(21,33,1.0),(21,34,1.0),(23,33,1.0),(23,34,1.0),(24,26,1.0),(24,28,1.0),(24,30,1.0),(24,33,1.0),(24,34,1.0),(25,26,1.0),(25,28,1.0),(25,32,1.0),(26,32,1.0),(27,30,1.0),(27,34,1.0),(28,34,1.0),(29,32,1.0),(29,34,1.0),(30,33,1.0),(30,34,1.0),(31,33,1.0),(31,34,1.0),(32,33,1.0),(32,34,1.0),(33,34,1.0)]


karate2com :: [[Node]]
karate2com = sort $ Prelude.map (sort) [[10, 29, 32, 25, 28, 26, 24, 30, 27, 34, 31, 33, 23, 15, 16, 21, 19], [3, 9, 8, 4, 14, 20, 2, 13, 22, 1, 18, 12, 5, 7, 6, 17]]


eU :: [LEdge Double]
eU = [
     (2,1,1)
    ,(1,2,1)
    
    ,(1,4,1)
    ,(4,1,1)
    
    ,(2,3,1)
    ,(3,2,1)
    
    ,(3,4,1)
    ,(4,3,1)
    
    ,(4,5,1)
    ,(5,4,1)
    ]

eD :: [LEdge Double]
eD = [
     (2,1,1)
    
    ,(1,4,1)
    
    ,(2,3,1)
    
    ,(3,4,1)
    
    ,(4,5,1)
    ]

gU :: Gr () Double
gU = mkGraph' eU

-- > prettyPrint gU
-- 1:()->[(1,2),(1,4)]
-- 2:()->[(1,1),(1,3)]
-- 3:()->[(1,2),(1,4)]
-- 4:()->[(1,1),(1,3),(1,5)]
-- 5:()->[(1,4)]

-- Visual representation:
-- 
--    2
--   / \
--  1   3
--   \ /
--    4
--    |
--    5
-- 
-- 

gD :: Gr () Double
gD = mkGraph' eD

eD' :: [LEdge Double]
eD' = [
     (2,1,1)
    
    ,(1,4,1)
    
    ,(2,3,1)
    
    ,(3,4,1)
    
    ,(4,5,1)
    ,(5,6,1)
    ,(5,7,1)
    ,(6,7,1)
    ]
gD' :: Gr () Double
gD' = mkGraph' eD'
