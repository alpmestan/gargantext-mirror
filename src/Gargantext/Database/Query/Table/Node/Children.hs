{-|
Module      : Gargantext.Database.Query.Table.Node.Children
Description : Main requests of Node to the database
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}


{-# OPTIONS_GHC -fno-warn-orphans        #-}

{-# LANGUAGE Arrows                      #-}

module Gargantext.Database.Query.Table.Node.Children
  where

import Control.Arrow (returnA)
import Data.Proxy
import Gargantext.Core
import Gargantext.Core.Types
import Gargantext.Database.Admin.Types.Hyperdata (HyperdataDocument, HyperdataContact)
import Gargantext.Database.Prelude
import Gargantext.Database.Query.Filter
import Gargantext.Database.Query.Table.NodeNode
import Gargantext.Database.Schema.Node
import Opaleye
import Protolude


-- TODO getAllTableDocuments
getAllDocuments :: HasDBid NodeType => ParentId -> Cmd err (TableResult (Node HyperdataDocument))
getAllDocuments pId = getAllChildren pId (Proxy :: Proxy HyperdataDocument)
                                         (Just NodeDocument)

-- TODO getAllTableContacts
getAllContacts :: HasDBid NodeType => ParentId -> Cmd err (TableResult (Node HyperdataContact))
getAllContacts pId = getAllChildren pId (Proxy :: Proxy HyperdataContact)
                                        (Just NodeContact)

getAllChildren :: (JSONB a, HasDBid NodeType)
               => ParentId
               -> proxy a
               -> Maybe NodeType
               -> Cmd err (NodeTableResult a)
getAllChildren pId p maybeNodeType = getChildren pId p maybeNodeType Nothing Nothing

getChildren :: (JSONB a, HasDBid NodeType)
            => ParentId
            -> proxy a
            -> Maybe NodeType
            -> Maybe Offset
            -> Maybe Limit
            -> Cmd err (NodeTableResult a)
getChildren pId _ maybeNodeType maybeOffset maybeLimit = do
  docs <- runOpaQuery
          $ limit' maybeLimit $ offset' maybeOffset
          $ orderBy (asc _node_id)
          $ query

  docCount <- runCountOpaQuery query

  pure $ TableResult { tr_docs = docs, tr_count = docCount }

  where
    query = selectChildren pId maybeNodeType

selectChildren :: HasDBid NodeType
               => ParentId
               -> Maybe NodeType
               -> Query NodeRead
selectChildren parentId maybeNodeType = proc () -> do
    row@(Node nId _ typeName _ parent_id _ _ _) <- queryNodeTable -< ()
    (NodeNode n1id n2id _ _) <- queryNodeNodeTable -< ()

    let nodeType = maybe 0 toDBid maybeNodeType
    restrict -< typeName  .== sqlInt4 nodeType

    restrict -< (.||) (parent_id .== (pgNodeId parentId))
                      ( (.&&) (n1id .== pgNodeId parentId)
                              (n2id .== nId))
    returnA -< row
