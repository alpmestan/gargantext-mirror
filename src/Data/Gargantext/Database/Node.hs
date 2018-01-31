{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE Arrows #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Data.Gargantext.Database.Node where

import Database.PostgreSQL.Simple.FromField ( Conversion
                                            , ResultError(ConversionFailed)
                                            , FromField
                                            , fromField
                                            , returnError
                                            )
import Database.PostgreSQL.Simple.Internal  (Field)
import Control.Arrow (returnA)
import Control.Lens.TH (makeLensesWith, abbreviatedFields)
import Data.Aeson
import Data.Gargantext.Types
import Data.Gargantext.Prelude
import Data.Maybe (Maybe, fromMaybe)
import Data.Text (Text)
import Data.Profunctor.Product.TH (makeAdaptorAndInstance)
import Data.Typeable (Typeable)
import qualified Data.ByteString.Internal as DBI
import Database.PostgreSQL.Simple (Connection)
import Opaleye

-- | Types for Node Database Management
data PGTSVector

type NodeWrite = NodePoly  (Maybe (Column PGInt4))  (Column PGInt4)
                                  (Column PGInt4)   (Column (Nullable PGInt4))
                                  (Column (PGText)) (Maybe (Column PGTimestamptz))
                                  (Column PGJsonb) -- (Maybe (Column PGTSVector))

type NodeRead = NodePoly  (Column PGInt4)   (Column PGInt4)
                          (Column PGInt4)   (Column (Nullable PGInt4))
                          (Column (PGText)) (Column PGTimestamptz)
                          (Column PGJsonb) -- (Column PGTSVector)

instance FromField HyperdataCorpus where
    fromField = fromField'

instance FromField HyperdataDocument where
    fromField = fromField'

instance FromField HyperdataProject where
    fromField = fromField'

instance FromField HyperdataUser where
    fromField = fromField'


fromField' :: (Typeable b, FromJSON b) => Field -> Maybe DBI.ByteString -> Conversion b
fromField' field mb = do
    v <- fromField field mb
    valueToHyperdata v
      where
          valueToHyperdata v = case fromJSON v of
             Success a  -> pure a
             Error _err -> returnError ConversionFailed field "cannot parse hyperdata"


instance QueryRunnerColumnDefault PGJsonb HyperdataDocument where
  queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataCorpus   where
  queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataProject  where
  queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataUser     where
  queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault (Nullable PGInt4) Int     where
  queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault (Nullable PGText) Text    where
  queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGInt4 Integer            where
    queryRunnerColumnDefault = fieldQueryRunnerColumn



$(makeAdaptorAndInstance "pNode" ''NodePoly)
$(makeLensesWith abbreviatedFields   ''NodePoly)


nodeTable :: Table NodeWrite NodeRead
nodeTable = Table "nodes" (pNode Node { node_id                = optional "id"
                                        , node_typename        = required "typename"
                                        , node_userId          = required "user_id"
                                        , node_parentId        = required "parent_id"
                                        , node_name            = required "name"
                                        , node_date            = optional "date"
                                        , node_hyperdata       = required "hyperdata"
                     --                   , node_titleAbstract   = optional "title_abstract"
                                        }
                            )


selectNodes :: Column PGInt4 -> Query NodeRead
selectNodes id = proc () -> do
    row <- queryNodeTable -< ()
    restrict -< node_id row .== id
    returnA -< row

runGetNodes :: Connection -> Query NodeRead -> IO [Document]
runGetNodes = runQuery


queryNodeTable :: Query NodeRead
queryNodeTable = queryTable nodeTable


selectNodeWithParentID :: Column (Nullable PGInt4) -> Query NodeRead
selectNodeWithParentID node_id = proc () -> do
    row@(Node _id _tn _u p_id _n _d _h) <- queryNodeTable -< ()
    -- restrict -< maybe (isNull p_id) (p_id .==) node_id
    restrict -< p_id .== node_id
    returnA -< row

selectNodesWithType :: Column PGInt4 -> Query NodeRead
selectNodesWithType type_id = proc () -> do
    row@(Node _ tn _ _ _ _ _) <- queryNodeTable -< ()
    restrict -< tn .== type_id
    returnA -< row

getNode :: Connection -> Column PGInt4 -> IO (Node Value)
getNode conn id = do
    fromMaybe (error "TODO: 404") . headMay <$> runQuery conn (limit 1 $ selectNodes id)

getNodesWithType :: Connection -> Column PGInt4 -> IO [Node Value]
getNodesWithType conn type_id = do
    runQuery conn $ selectNodesWithType type_id

-- NP check type
getNodesWithParentId :: Connection -> Column (Nullable PGInt4) -> IO [Node Value]
getNodesWithParentId conn node_id = do
    runQuery conn $ selectNodeWithParentID node_id

-- NP check type
getCorpusDocument :: Connection -> Column PGInt4 -> IO [Document]
getCorpusDocument conn node_id = runQuery conn (selectNodeWithParentID $ toNullable node_id)

-- NP check type
getProjectCorpora :: Connection -> Column (Nullable PGInt4) -> IO [Corpus]
getProjectCorpora conn node_id = do
    runQuery conn $ selectNodeWithParentID node_id
