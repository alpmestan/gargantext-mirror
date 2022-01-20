{-|
Module      : Gargantext.Database.Schema.NodeNodeNgrams
Description : TODO: remove this module and table in database
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

-}

{-#  OPTIONS_GHC -fno-warn-orphans  #-}

{-# LANGUAGE Arrows                 #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE TemplateHaskell        #-}

module Gargantext.Database.Schema.ContextNodeNgrams
  where

import Prelude
import Gargantext.Database.Schema.Prelude
import Gargantext.Database.Schema.Ngrams (NgramsTypeId, NgramsId)
import Gargantext.Database.Admin.Types.Node



type ContextNodeNgrams =
  ContextNodeNgramsPoly ContextId ListId NgramsId NgramsTypeId Double


data ContextNodeNgramsPoly c n ngrams_id ngt w
   = ContextNodeNgrams { _cnng_context_id   :: !c
                       , _cnng_node_id      :: !n
                       , _cnng_ngrams_id    :: !ngrams_id
                       , _cnng_ngramsType   :: !ngt
                       , _cnng_weight       :: !w
                       } deriving (Show)

type ContextNodeNgramsWrite =
     ContextNodeNgramsPoly (Column SqlInt4  )
                           (Column SqlInt4  )
                           (Column SqlInt4  )
                           (Column SqlInt4  )
                           (Column SqlFloat8)

type ContextNodeNgramsRead  =
     ContextNodeNgramsPoly (Column SqlInt4  )
                           (Column SqlInt4  )
                           (Column SqlInt4  )
                           (Column SqlInt4  )
                           (Column SqlFloat8)

type ContextNodeNgramsReadNull =
     ContextNodeNgramsPoly (Column (Nullable SqlInt4  ))
                           (Column (Nullable SqlInt4  ))
                           (Column (Nullable SqlInt4  ))
                           (Column (Nullable SqlInt4  ))
                           (Column (Nullable SqlFloat8))

$(makeAdaptorAndInstance "pContextNodeNgrams" ''ContextNodeNgramsPoly)
makeLenses ''ContextNodeNgramsPoly


contextNodeNgramsTable :: Table ContextNodeNgramsWrite ContextNodeNgramsRead
contextNodeNgramsTable  = Table "context_node_ngrams"
                          ( pContextNodeNgrams ContextNodeNgrams
                               { _cnng_context_id = requiredTableField "context_id"
                               , _cnng_node_id    = requiredTableField "node_id"
                               , _cnng_ngrams_id  = requiredTableField "ngrams_id"
                               , _cnng_ngramsType = requiredTableField "ngrams_type"
                               , _cnng_weight     = requiredTableField "weight"
                               }
                          )
