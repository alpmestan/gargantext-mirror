{-|
Module      : Gargantext.Core.Text.List.Social
Description :
Copyright   : (c) CNRS, 2018-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}

module Gargantext.Core.Text.List.Social
  where

-- findList imports
import Gargantext.Core.Types.Individu
import Gargantext.Database.Admin.Config
import Gargantext.Database.Admin.Types.Node
import Gargantext.Database.Prelude
import Gargantext.Database.Query.Table.Node.Error
import Gargantext.Database.Query.Tree
import Gargantext.Database.Query.Tree.Root (getRootId)
import Gargantext.Prelude

-- filterList imports
import Data.Maybe (fromMaybe)
import Data.Map (Map)
import Data.Set (Set)
import Data.Semigroup (Semigroup(..))
import Data.Text (Text)
import Gargantext.API.Ngrams.Tools -- (getListNgrams)
import Gargantext.API.Ngrams.Types
import Gargantext.Core.Types.Main
import Gargantext.Database.Schema.Ngrams
import Gargantext.Core.Text.List.Social.Find
import Gargantext.Core.Text.List.Social.Group
import Gargantext.Core.Text.List.Social.ListType
import qualified Data.List  as List
import qualified Data.Map   as Map
import qualified Data.Set   as Set

------------------------------------------------------------------------
flowSocialList :: ( RepoCmdM env err m
                  , CmdM     env err m
                  , HasNodeError err
                  , HasTreeError err
                  )
                  => User -> NgramsType -> Set Text
                  -> m (Map ListType (Set Text))
flowSocialList user nt ngrams' = do
  privateLists <- flowSocialListByMode Private user nt ngrams'
  -- printDebug "* privateLists *: \n" privateLists
  -- here preference to privateLists (discutable)
  sharedLists  <- flowSocialListByMode Shared  user nt (termsByList CandidateTerm privateLists)
  -- printDebug "* sharedLists *: \n" sharedLists
   -- TODO publicMapList

  let result = unions [ Map.mapKeys (fromMaybe CandidateTerm) privateLists
                      , Map.mapKeys (fromMaybe CandidateTerm) sharedLists
                      ]
  -- printDebug "* socialLists *: results \n" result
  pure result

------------------------------------------------------------------------
unions :: (Ord a, Semigroup a, Semigroup b, Ord b)
      => [Map a (Set b)] -> Map a (Set b)
unions = invertBack . Map.unionsWith (<>) . map invertForw

invertForw :: (Ord b, Semigroup a) => Map a (Set b) -> Map b a
invertForw = Map.unionsWith (<>)
           . (map (\(k,sets) -> Map.fromSet (\_ -> k) sets))
           . Map.toList

invertBack :: (Ord a, Ord b) => Map b a -> Map a (Set b)
invertBack = Map.fromListWith (<>)
           . (map (\(b,a) -> (a, Set.singleton b)))
           .  Map.toList

unions_test :: Map ListType (Set Text)
unions_test = unions [m1, m2]
  where
    m1 = Map.fromList [ (StopTerm     , Set.singleton "Candidate")]
    m2 = Map.fromList [ (CandidateTerm, Set.singleton "Candidate")
                      , (MapTerm      , Set.singleton "Candidate")
                      ]

------------------------------------------------------------------------
flowSocialListByMode :: ( RepoCmdM env err m
                        , CmdM     env err m
                        , HasNodeError err
                        , HasTreeError err
                        )
                     => NodeMode -> User -> NgramsType -> Set Text
                     -> m (Map (Maybe ListType) (Set Text))
flowSocialListByMode mode user nt ngrams' = do
  listIds <- findListsId mode user
  case listIds of
    [] -> pure $ Map.fromList [(Nothing, ngrams')]
    _  -> do
      counts  <- countFilterList ngrams' nt listIds Map.empty
      -- printDebug "flowSocialListByMode counts" counts
      let r = toSocialList counts ngrams'
      -- printDebug "flowSocialListByMode r" r
      pure r

------------------------------------------------------------------------
-- TODO: maybe use social groups too
toSocialList :: Map Text (Map ListType Int)
             -> Set Text
             -> Map (Maybe ListType) (Set Text)
toSocialList m = Map.fromListWith (<>)
               . Set.toList
               . Set.map (toSocialList1 m)

-- | TODO what if equality ?
-- choice depends on Ord instance of ListType
-- for now : data ListType  =  StopTerm | CandidateTerm | MapTerm
-- means MapTerm > CandidateTerm > StopTerm in case of equality of counts
-- (we minimize errors on MapTerms if doubt)
toSocialList1 :: Map Text (Map ListType Int)
             -> Text
             -> (Maybe ListType, Set Text)
toSocialList1 m t = case Map.lookup t m of
  Nothing -> (Nothing, Set.singleton t)
  Just  m' -> ( (fst . fst) <$> Map.maxViewWithKey m'
              , Set.singleton t
              )

toSocialList1_testIsTrue :: Bool
toSocialList1_testIsTrue = result == (Just MapTerm, Set.singleton token)
  where
    result = toSocialList1 (Map.fromList [(token, m)]) token
    token  = "token"
    m = Map.fromList [ (CandidateTerm, 1)
                     , (MapTerm      , 2)
                     , (StopTerm     , 3)
                     ]

