{-|
Module      : Gargantext.Database.Action.User
Description :
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX
-}

{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# OPTIONS_GHC -fno-warn-orphans        #-}

module Gargantext.Database.Action.User
  where

-- import Data.Maybe (catMaybes)
import Gargantext.Database.Query.Table.User
import Gargantext.Core.Types.Individu
import Gargantext.Database.Prelude
import Gargantext.Prelude
import Gargantext.Prelude.Mail (gargMail)
import Gargantext.Database.Query.Table.Node.Error (HasNodeError(..), nodeError, NodeError(..))
import Gargantext.Database.Action.Flow (getOrMkRoot)


------------------------------------------------------------------------
mkUser :: HasNodeError err => NewUser GargPassword -> Cmd err Int64
mkUser u = mkUsers [u]

mkUsers :: HasNodeError err => [NewUser GargPassword] -> Cmd err Int64
mkUsers us = do
  us' <- liftBase    $ mapM toUserHash us
  r   <- insertUsers $ map toUserWrite us'
  _   <- mapM getOrMkRoot $ map (\u -> UserName (_nu_username u)) us
  _   <- liftBase gargMail
  pure r

------------------------------------------------------------------------
rmUser :: HasNodeError err => User -> Cmd err Int64
rmUser (UserName un) = deleteUsers [un]
rmUser _ = nodeError NotImplYet

-- TODO
rmUsers :: HasNodeError err => [User] -> Cmd err Int64
rmUsers [] = pure 0
rmUsers _  = undefined
