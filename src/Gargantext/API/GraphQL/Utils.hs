module Gargantext.API.GraphQL.Utils where

import Data.Morpheus.Types (GQLTypeOptions, fieldLabelModifier)
import qualified Data.Text as T
import Gargantext.Core.Utils.Prefix (unCapitalize, dropPrefix)
import Gargantext.Prelude

unPrefix :: T.Text -> GQLTypeOptions -> GQLTypeOptions
unPrefix prefix options = options { fieldLabelModifier = nflm }
  where
    nflm label = unCapitalize $ dropPrefix (T.unpack prefix) $ ( fieldLabelModifier options ) label