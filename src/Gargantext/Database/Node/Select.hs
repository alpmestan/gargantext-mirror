{-|
Module      : Gargantext.Database.Node.Select
Description : Main requests of Node to the database
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}


{-# LANGUAGE Arrows                 #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FlexibleContexts       #-}

module Gargantext.Database.Node.Select where

import Opaleye
import Gargantext.Core.Types
import Gargantext.Database.Schema.Node
import Gargantext.Database.Utils
import Gargantext.Database.Config
import Gargantext.Database.Schema.User
import Gargantext.Core.Types.Individu (Username)
import Control.Arrow (returnA)

--{-
selectNodesWithUsername :: NodeType -> Username -> Cmd err [NodeId]
selectNodesWithUsername nt u = runOpaQuery (q u)
  where
    
    join :: Query (NodeRead, UserReadNull)
    join = leftJoin queryNodeTable queryUserTable on1
      where
        on1 (n,us) = _node_userId n .== user_id us
    
    q u' = proc () -> do
    (n,usrs) <- join -< ()
    restrict -< user_username usrs .== (toNullable $ pgStrictText u')
    restrict -< _node_typename n .== (pgInt4 $ nodeTypeId nt)
    returnA  -< _node_id n


