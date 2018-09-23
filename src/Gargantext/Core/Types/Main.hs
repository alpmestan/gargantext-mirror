{-|
Module      : Gargantext.Core.Types.Main
Description : Short description
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

-}

{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

-----------------------------------------------------------------------
module Gargantext.Core.Types.Main where
------------------------------------------------------------------------

import Data.Aeson (FromJSON, ToJSON, toJSON)
import Data.Aeson as A
import Data.Aeson.TH (deriveJSON)
import Data.Eq (Eq())
import Data.Monoid ((<>))
import Data.Text (Text)
import Data.Swagger

import Gargantext.Database.Types.Node
import Gargantext.Core.Utils.Prefix (unPrefix)
import Gargantext.Prelude

import GHC.Generics (Generic)
import Test.QuickCheck (elements)
import Test.QuickCheck.Arbitrary (Arbitrary, arbitrary)

------------------------------------------------------------------------
data NodeTree = NodeTree { _nt_name :: Text
                         , _nt_type :: NodeType
                         , _nt_id   :: Int
                         } deriving (Show, Read, Generic)

$(deriveJSON (unPrefix "_nt_") ''NodeTree)
------------------------------------------------------------------------

-- Garg Network is a network of all Garg nodes
--gargNetwork = undefined

-- | Garg Node is Database Schema Typed as specification
-- gargNode gathers all the Nodes of all users on one Node
gargNode :: [Tree NodeTree]
gargNode = [userTree]

-- | User Tree simplified
userTree :: Tree NodeTree
userTree = TreeN (NodeTree "user name" NodeUser 1) $
                  [leafT $ NodeTree "MyPage" UserPage 0] <>
                  [annuaireTree, projectTree]

-- | Project Tree
projectTree :: Tree NodeTree
projectTree = TreeN (NodeTree "Project CNRS/IMT" Project 2) [corpusTree 10 "A", corpusTree 20 "B"]

type Individu  = Document

-- | Corpus Tree
annuaireTree :: Tree NodeTree
annuaireTree = TreeN (NodeTree "Annuaire" Annuaire 41) (   [leafT $ NodeTree "IMT"  Individu 42]
                                                        <> [leafT $ NodeTree "CNRS" Individu 43]
                          )

corpusTree :: NodeId -> Text -> Tree NodeTree
corpusTree nId t  = TreeN (NodeTree ("Corpus " <> t)  NodeCorpus nId) (  [ leafT $ NodeTree "Documents" Document (nId +1)]
--                                                      <> [ leafT $ NodeTree "My lists"  Lists    5]
--                          <> [ leafT (NodeTree "Metrics A" Metrics 6)  ]
--                          <> [ leafT (NodeTree "Class A" Classification 7)]
                          )

--   TODO make instances of Nodes
-- NP
-- - why NodeUser and not just User ?
-- - is this supposed to hold data ?
-- AD : Yes, some preferences for instances

data Parent = NodeType NodeId

--data Classification = Favorites | MyClassifcation

data Lists  =  StopList    | MainList | MapList | GroupList

-- data Metrics = Occurrences | Cooccurrences | Specclusion | Genclusion | Cvalue
--              | TfidfCorpus | TfidfGlobal   | TirankLocal | TirankGlobal


-- | Community Manager Use Case
type Annuaire  = NodeCorpus

-- | Favorites Node enable Node categorization
type Favorites = Node HyperdataFavorites

-- | Favorites Node enable Swap Node with some synonyms for clarity
type NodeSwap  = Node HyperdataResource

-- | Then a Node can be a List which has some synonyms
type List = Node HyperdataList
type StopList   = List
type MainList   = List
type MapList    = List
type GroupList  = List

-- | Then a Node can be a Score which has some synonyms
type Score = Node HyperdataScore
type Occurrences   = Score
type Cooccurrences = Score
type Specclusion   = Score
type Genclusion    = Score
type Cvalue        = Score
type Tficf         = Score
---- TODO All these Tfidf* will be replaced with TFICF
type TfidfCorpus   = Tficf
type TfidfGlobal   = Tficf
type TirankLocal   = Tficf
type TirankGlobal  = Tficf
--
---- | Then a Node can be either a Graph or a Phylo or a Notebook
type Graph    = Node HyperdataGraph
type Phylo    = Node HyperdataPhylo
type Notebook = Node HyperdataNotebook


-- Temporary types to be removed
type ErrorMessage = Text

-- Queries
type ParentId = NodeId
type Limit    = Int
type Offset   = Int


------------------------------------------------------------------------
-- All the Database is structred like a hierarchical Tree
data Tree a = TreeN a [Tree a]
  deriving (Show, Read, Eq, Generic)

instance ToJSON   (Tree NodeTree) where
  toJSON (TreeN node nodes) =
    object ["node" A..= toJSON node, "children" A..= toJSON nodes]

instance FromJSON (Tree NodeTree)

instance ToSchema NodeTree
instance ToSchema  (Tree NodeTree)
instance Arbitrary (Tree NodeTree) where
  arbitrary = elements [userTree, userTree]

-- data Tree a = NodeT a [Tree a]
-- same as Data.Tree
leafT :: a -> Tree a
leafT x = TreeN x []