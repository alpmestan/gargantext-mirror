{-|
Module      : Gargantext.Database.Types.Nodes
Description : Main Types of Nodes in Database
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE BangPatterns               #-}
{-# LANGUAGE TemplateHaskell            #-}

-- {-# LANGUAGE DuplicateRecordFields #-}

module Gargantext.Database.Admin.Types.Node
  where

import Codec.Serialise (Serialise())
import Control.Monad (mzero)
import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Either
import Data.Hashable (Hashable)
import Data.Morpheus.Types (GQLType)
import Data.Swagger
import Data.Text (Text, unpack)
import Data.Time (UTCTime)
import Database.PostgreSQL.Simple.FromField (FromField, fromField)
import Database.PostgreSQL.Simple.ToField (ToField, toField)
import GHC.Generics (Generic)
import Servant
import qualified Opaleye as O
import Opaleye (DefaultFromField, defaultFromField, PGInt4, PGText, PGTSVector, Nullable, fieldQueryRunnerColumn)
import Test.QuickCheck (elements)
import Gargantext.Prelude.Crypto.Hash (Hash)
import Test.QuickCheck.Arbitrary
import Test.QuickCheck.Instances.Text ()
import Test.QuickCheck.Instances.Time ()
import Text.Read (read)

import Gargantext.Core.Utils.Prefix (unPrefix, unPrefixSwagger, wellNamedSchema)
-- import Gargantext.Database.Prelude (fromField')
import Gargantext.Database.Schema.Node
import Gargantext.Prelude

type UserId = Int
type MasterUserId = UserId
------------------------------------------------------------------------
-- | NodePoly indicates that Node has a Polymorphism Type
type Node json   = NodePoly NodeId (Maybe Hash) NodeTypeId UserId (Maybe ParentId) NodeName UTCTime json

-- | NodeSearch (queries)
-- type NodeSearch json   = NodePolySearch NodeId NodeTypeId UserId (Maybe ParentId) NodeName UTCTime json (Maybe TSVector)

------------------------------------------------------------------------

instance (Typeable hyperdata, ToSchema hyperdata) =>
         ToSchema (NodePoly NodeId Hash NodeTypeId
                            (Maybe UserId)
                            ParentId NodeName
                            UTCTime hyperdata
                  ) where
  declareNamedSchema = wellNamedSchema "_node_"

instance (Typeable hyperdata, ToSchema hyperdata) =>
         ToSchema (NodePoly NodeId Hash NodeTypeId
                            UserId
                            (Maybe ParentId) NodeName
                            UTCTime hyperdata
                  ) where
  declareNamedSchema = wellNamedSchema "_node_"

instance (Typeable hyperdata, ToSchema hyperdata) =>
         ToSchema (NodePoly NodeId (Maybe Hash) NodeTypeId
                            UserId
                            (Maybe ParentId) NodeName
                            UTCTime hyperdata
                  ) where
  declareNamedSchema = wellNamedSchema "_node_"

instance (Typeable hyperdata, ToSchema hyperdata) =>
         ToSchema (NodePolySearch NodeId
                                  NodeTypeId
                                  (Maybe UserId)
                                  ParentId
                                  NodeName
                                  UTCTime
                                  hyperdata
                                  (Maybe TSVector)
                  ) where
  declareNamedSchema = wellNamedSchema "_ns_"

instance (Typeable hyperdata, ToSchema hyperdata) =>
         ToSchema (NodePolySearch NodeId
                                  NodeTypeId
                                  UserId
                                  (Maybe ParentId)
                                  NodeName
                                  UTCTime
                                  hyperdata
                                  (Maybe TSVector)
                  ) where
  declareNamedSchema = wellNamedSchema "_ns_"

instance (Arbitrary nodeId
         ,Arbitrary hashId
         ,Arbitrary toDBid
         ,Arbitrary userId
         ,Arbitrary nodeParentId
         , Arbitrary hyperdata
         ) => Arbitrary (NodePoly nodeId hashId toDBid userId nodeParentId
                                  NodeName UTCTime hyperdata) where
    --arbitrary = Node 1 1 (Just 1) 1 "name" (jour 2018 01 01) (arbitrary) (Just "")
    arbitrary = Node <$> arbitrary <*> arbitrary <*> arbitrary
                     <*> arbitrary <*> arbitrary <*> arbitrary
                     <*> arbitrary <*> arbitrary

instance (Arbitrary hyperdata
         ,Arbitrary nodeId
         ,Arbitrary toDBid
         ,Arbitrary userId
         ,Arbitrary nodeParentId
         ) => Arbitrary (NodePolySearch nodeId
                                        toDBid
                                        userId
                                        nodeParentId
                                        NodeName
                                        UTCTime
                                        hyperdata
                                        (Maybe TSVector)
                        ) where
    --arbitrary = Node 1 1 (Just 1) 1 "name" (jour 2018 01 01) (arbitrary) (Just "")
    arbitrary = NodeSearch <$> arbitrary
                           <*> arbitrary
                           <*> arbitrary
                           <*> arbitrary
                           <*> arbitrary
                           <*> arbitrary
                           <*> arbitrary
                           <*> arbitrary

------------------------------------------------------------------------
pgNodeId :: NodeId -> O.Column O.PGInt4
pgNodeId = O.sqlInt4 . id2int
  where
    id2int :: NodeId -> Int
    id2int (NodeId n) = n

------------------------------------------------------------------------
newtype NodeId = NodeId Int
  deriving (Read, Generic, Num, Eq, Ord, Enum, ToJSONKey, FromJSONKey, ToJSON, FromJSON, Hashable)
instance GQLType NodeId
instance Show NodeId where
  show (NodeId n) = "nodeId-" <> show n
instance Serialise NodeId
instance ToField NodeId where
  toField (NodeId n) = toField n
instance FromField NodeId where
  fromField field mdata = do
    n <- fromField field mdata
    if (n :: Int) > 0
       then return $ NodeId n
       else mzero
instance ToSchema NodeId

unNodeId :: NodeId -> Int
unNodeId (NodeId n) = n

type NodeTypeId   = Int
type NodeName     = Text
type TSVector     = Text

------------------------------------------------------------------------
------------------------------------------------------------------------
instance FromHttpApiData NodeId where
  parseUrlPiece n = pure $ NodeId $ (read . cs) n

instance ToParamSchema NodeId
instance Arbitrary NodeId where
  arbitrary = NodeId <$> arbitrary

type ParentId = NodeId
type CorpusId    = NodeId
type CommunityId = NodeId
type ListId   = NodeId
type DocumentId = NodeId
type DocId      = NodeId
type RootId     = NodeId
type MasterCorpusId = CorpusId
type UserCorpusId   = CorpusId

type GraphId  = NodeId
type PhyloId  = NodeId
type AnnuaireId = NodeId
type ContactId  = NodeId

------------------------------------------------------------------------
data Status  = Status { status_failed    :: !Int
                      , status_succeeded :: !Int
                      , status_remaining :: !Int
                      } deriving (Show, Generic)
$(deriveJSON (unPrefix "status_") ''Status)

instance Arbitrary Status where
  arbitrary = Status <$> arbitrary <*> arbitrary <*> arbitrary


------------------------------------------------------------------------
data LanguageNodes = LanguageNodes { languageNodes___unknown__ :: [Int]}
    deriving (Show, Generic)
$(deriveJSON (unPrefix "languageNodes_") ''LanguageNodes)

------------------------------------------------------------------------
-- level: debug | dev  (fatal = critical)
data EventLevel = CRITICAL | FATAL | ERROR | WARNING | INFO | DEBUG
  deriving (Show, Generic, Enum, Bounded)

instance FromJSON EventLevel
instance ToJSON EventLevel

instance Arbitrary EventLevel where
  arbitrary = elements [minBound..maxBound]

instance ToSchema EventLevel where
  declareNamedSchema proxy = genericDeclareNamedSchema defaultSchemaOptions proxy

------------------------------------------------------------------------
data Event = Event { event_level   :: !EventLevel
                   , event_message :: !Text
                   , event_date    :: !UTCTime
            } deriving (Show, Generic)
$(deriveJSON (unPrefix "event_") ''Event)

instance Arbitrary Event where
  arbitrary = Event <$> arbitrary <*> arbitrary <*> arbitrary

instance ToSchema Event where
  declareNamedSchema = genericDeclareNamedSchema (unPrefixSwagger "event_")

------------------------------------------------------------------------
data Resource = Resource { resource_path    :: !(Maybe Text)
                         , resource_scraper :: !(Maybe Text)
                         , resource_query   :: !(Maybe Text)
                         , resource_events  :: !([Event])
                         , resource_status  :: !Status
                         , resource_date    :: !UTCTime
                         } deriving (Show, Generic)
$(deriveJSON (unPrefix "resource_") ''Resource)

instance Arbitrary Resource where
    arbitrary = Resource <$> arbitrary
                         <*> arbitrary
                         <*> arbitrary
                         <*> arbitrary
                         <*> arbitrary
                         <*> arbitrary

instance ToSchema Resource where
  declareNamedSchema = genericDeclareNamedSchema (unPrefixSwagger "resource_")

------------------------------------------------------------------------
-- | Then a Node can be either a Folder or a Corpus or a Document
data NodeType = NodeUser
              | NodeFolderPrivate
              | NodeFolderShared | NodeTeam
              | NodeFolderPublic
              | NodeFolder

              -- | NodeAnalysis | NodeCommunity

              | NodeCorpus     | NodeCorpusV3 | NodeTexts | NodeDocument
              | NodeAnnuaire   | NodeContact
              | NodeGraph      | NodePhylo
              | NodeDashboard  -- | NodeChart    | NodeNoteBook
              | NodeList       | NodeModel
              | NodeListCooc

{-
              -- | Metrics
              -- | NodeOccurrences
              -- | Classification
-}

              -- Optional Nodes
              | NodeFrameWrite | NodeFrameCalc | NodeFrameVisio | NodeFrameNotebook
              | NodeFile

  deriving (Show, Read, Eq, Generic, Bounded, Enum)


allNodeTypes :: [NodeType]
allNodeTypes = [minBound ..]

defaultName :: NodeType -> Text
defaultName NodeUser       = "User"
defaultName NodeContact    = "Contact"

defaultName NodeCorpus     = "Corpus"
defaultName NodeCorpusV3   = "Corpus"
defaultName NodeAnnuaire   = "Annuaire"

defaultName NodeDocument   = "Doc"
defaultName NodeTexts      = "Docs"
defaultName NodeList       = "List"
defaultName NodeListCooc   = "List"
defaultName NodeModel      = "Model"

defaultName NodeFolder     = "Folder"
defaultName NodeFolderPrivate = "Private Folder"
defaultName NodeFolderShared  = "Shared Folder"
defaultName NodeTeam          = "Folder"
defaultName NodeFolderPublic  = "Public Folder"

defaultName NodeDashboard     = "Board"
defaultName NodeGraph         = "Graph"
defaultName NodePhylo         = "Phylo"

defaultName NodeFrameWrite    = "Frame Write"
defaultName NodeFrameCalc     = "Frame Calc"
defaultName NodeFrameVisio    = "Frame Visio"
defaultName NodeFrameNotebook     = "Frame Code"

defaultName NodeFile          = "File"


instance FromJSON NodeType
instance ToJSON NodeType

instance FromHttpApiData NodeType
  where
      parseUrlPiece = Right . read . unpack

instance ToParamSchema NodeType
instance ToSchema      NodeType

instance Arbitrary NodeType where
  arbitrary = elements allNodeTypes



------------------------------------------------------------------------
-- Instances
------------------------------------------------------------------------
instance ToSchema Status where
  declareNamedSchema = genericDeclareNamedSchema (unPrefixSwagger "status_")

------------------------------------------------------------------------
{-
instance FromField (NodeId, Text)
  where
    fromField = fromField'
-}
------------------------------------------------------------------------
instance DefaultFromField PGTSVector (Maybe TSVector)
  where
    defaultFromField = fieldQueryRunnerColumn

instance DefaultFromField PGInt4 (Maybe NodeId)
  where
    defaultFromField = fieldQueryRunnerColumn

instance DefaultFromField PGInt4 NodeId
  where
    defaultFromField = fieldQueryRunnerColumn

instance DefaultFromField (Nullable PGInt4) NodeId
  where
    defaultFromField = fieldQueryRunnerColumn

instance (DefaultFromField (Nullable O.PGTimestamptz) UTCTime)
  where
    defaultFromField = fieldQueryRunnerColumn

instance DefaultFromField PGText (Maybe Hash)
  where
    defaultFromField = fieldQueryRunnerColumn


