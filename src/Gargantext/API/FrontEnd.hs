{-|
Module      : Gargantext.API.FrontEnd
Description : Server FrontEnd API
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Loads all static file for the front-end.

-}

{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE TemplateHaskell   #-}

---------------------------------------------------------------------
module Gargantext.API.FrontEnd where

import Servant.Static.TH (createApiAndServerDecs)

---------------------------------------------------------------------
$(createApiAndServerDecs "FrontEndAPI" "frontEndServer" "purescript-gargantext/dist")
---------------------------------------------------------------------

