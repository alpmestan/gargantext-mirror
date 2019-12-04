{-|
Module      : Gargantext.Database.Node.Children
Description : Main requests of Node to the database
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}

{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# OPTIONS_GHC -fno-warn-orphans        #-}

{-# LANGUAGE Arrows                 #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE RankNTypes             #-}

module Gargantext.Database.Node.Children where

import Data.Proxy
import Opaleye
import Gargantext.Core.Types
import Gargantext.Database.Schema.Node
import Gargantext.Database.Utils
import Gargantext.Database.Schema.NodeNode
import Gargantext.Database.Config (nodeTypeId)
import Gargantext.Database.Queries.Filter
import Gargantext.Database.Node.Contact (HyperdataContact)
import Gargantext.Database.Schema.Node (pgNodeId)
import Control.Arrow (returnA)

getAllDocuments :: ParentId -> Cmd err [Node HyperdataDocument]
getAllDocuments pId = getAllChildren pId (Proxy :: Proxy HyperdataDocument)
                                         (Just NodeDocument)

getAllContacts :: ParentId -> Cmd err [Node HyperdataContact]
getAllContacts pId = getAllChildren pId (Proxy :: Proxy HyperdataContact)
                                        (Just NodeContact)

getAllChildren :: JSONB a
               => ParentId
               -> proxy a
               -> Maybe NodeType
               -> Cmd err [Node a]
getAllChildren pId p maybeNodeType = getChildren pId p maybeNodeType Nothing Nothing

getChildren :: JSONB a
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
          $ selectChildren pId maybeNodeType
  allDocs <- runOpaQuery
          $ limit' Nothing $ offset' Nothing
          $ selectChildren pId maybeNodeType

  pure $ NodeTableResult { tr_docs = docs, tr_count = (length allDocs) }

selectChildren :: ParentId
               -> Maybe NodeType
               -> Query NodeRead
selectChildren parentId maybeNodeType = proc () -> do
    row@(Node nId typeName _ parent_id _ _ _) <- queryNodeTable -< ()
    (NodeNode n1id n2id _ _) <- queryNodeNodeTable -< ()

    let nodeType = maybe 0 nodeTypeId maybeNodeType
    restrict -< typeName  .== pgInt4 nodeType

    restrict -< (.||) (parent_id .== (pgNodeId parentId))
                      ( (.&&) (n1id .== pgNodeId parentId)
                              (n2id .== nId))
    returnA -< row
