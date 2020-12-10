{-|
Module      : Gargantext.Core.Text.List.Social.History
Description :
Copyright   : (c) CNRS, 2018-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}

module Gargantext.Core.Text.List.Social.History
  where

import Data.Map (Map)
import Control.Lens (view)
import Gargantext.API.Ngrams.Types
import Gargantext.Prelude
import Gargantext.Core.Types (ListType(..), ListId, NodeId)
import qualified Data.Map.Strict.Patch as PatchMap
import qualified Data.Map.Strict as Map
import qualified Data.List as List
import Gargantext.Database.Schema.Ngrams (NgramsType(..))


userHistory :: [NgramsType]
        -> [ListId]
        -> Repo s NgramsStatePatch
        -> Map NgramsType (Map ListId [Map NgramsTerm NgramsPatch])
userHistory t l r = clean $ history t l r
  where
    clean = Map.map (Map.map List.init)


history :: [NgramsType]
        -> [ListId]
        -> Repo s NgramsStatePatch
        -> Map NgramsType (Map ListId [Map NgramsTerm NgramsPatch])
history types lists = merge
                    . map (Map.map ( Map.map cons))
                    . map (Map.map ((Map.filterWithKey (\k _ -> List.elem k lists))))
                    . map           (Map.filterWithKey (\k _ -> List.elem k types))
                    . map toMap
                    . view r_history
  where
    cons a = [a]


merge :: [Map NgramsType (Map ListId [Map NgramsTerm NgramsPatch])]
      ->  Map NgramsType (Map ListId [Map NgramsTerm NgramsPatch])
merge = Map.unionsWith merge'
  where
    merge' :: Map ListId [Map NgramsTerm NgramsPatch]
           -> Map ListId [Map NgramsTerm NgramsPatch]
           -> Map ListId [Map NgramsTerm NgramsPatch]
    merge' = Map.unionWith (<>)


toMap :: PatchMap NgramsType
           (PatchMap NodeId
            (NgramsTablePatch
            )
          )
        -> Map NgramsType
           (Map ListId
            (Map NgramsTerm NgramsPatch
            )
           )
toMap = Map.map (Map.map unNgramsTablePatch) . (Map.map toMap') . toMap'
  where
    toMap' :: Ord a => PatchMap a b -> Map a b
    toMap' = Map.fromList . PatchMap.toList

    unNgramsTablePatch :: NgramsTablePatch -> Map NgramsTerm NgramsPatch
    unNgramsTablePatch (NgramsTablePatch p) = toMap' p

