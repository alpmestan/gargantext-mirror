{-|
Module      : Gargantext.Database.Schema.Node
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
{-# LANGUAGE DeriveGeneric          #-}
{-# LANGUAGE ConstraintKinds        #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE OverloadedStrings      #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE NoImplicitPrelude      #-}
{-# LANGUAGE RankNTypes             #-}
{-# LANGUAGE TemplateHaskell        #-}

module Gargantext.Database.Schema.Node where

import Control.Arrow (returnA)
import Control.Lens (Prism', set, view, (#), (^?))
import Control.Lens.TH (makeLensesWith, abbreviatedFields)
import Control.Monad.Error.Class (MonadError(..))
import Data.Aeson
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Profunctor.Product.TH (makeAdaptorAndInstance)
import Data.Text (Text, pack)
import Database.PostgreSQL.Simple.FromField (FromField, fromField)
import GHC.Int (Int64)
import Gargantext.Core (Lang(..))
import Gargantext.Core.Types
import Gargantext.Core.Types.Individu (Username)
import Gargantext.Core.Types.Main (UserId)
import Gargantext.Database.Config (nodeTypeId)
import Gargantext.Database.Queries.Filter (limit', offset')
import Gargantext.Database.Types.Node (NodeType, defaultCorpus, Hyperdata)
import Gargantext.Database.Utils
import Gargantext.Prelude hiding (sum, head)
import Opaleye hiding (FromField)
import Opaleye.Internal.QueryArr (Query)
import Prelude hiding (null, id, map, sum)

------------------------------------------------------------------------

data NodeError = NoListFound
  deriving (Show)

class HasNodeError e where
  _NodeError :: Prism' e NodeError

nodeError :: (MonadError e m, HasNodeError e) => NodeError -> m a
nodeError ne = throwError $ _NodeError # ne

catchNodeError :: (MonadError e m, HasNodeError e) => m a -> (NodeError -> m a) -> m a
catchNodeError f g = catchError f (\e -> maybe (throwError e) g (e ^? _NodeError))

------------------------------------------------------------------------
type AnnuaireId = Int

type DocId  = Int
type TypeId = Int
------------------------------------------------------------------------
instance FromField HyperdataAny where
    fromField = fromField'

instance FromField HyperdataCorpus
  where
    fromField = fromField'

instance FromField HyperdataDocument
  where
    fromField = fromField'

instance FromField HyperdataDocumentV3
  where
    fromField = fromField'

instance FromField HyperdataUser
  where
    fromField = fromField'

instance FromField HyperdataList
  where
    fromField = fromField'

instance FromField HyperdataGraph
  where
    fromField = fromField'

instance FromField HyperdataAnnuaire
  where
    fromField = fromField'
------------------------------------------------------------------------
instance QueryRunnerColumnDefault PGJsonb HyperdataAny
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataDocument
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataDocumentV3
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataCorpus
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataUser
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataList
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataGraph
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGJsonb HyperdataAnnuaire
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGTSVector (Maybe TSVector)
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

instance QueryRunnerColumnDefault PGInt4 (Maybe NodeParentId)
  where
    queryRunnerColumnDefault = fieldQueryRunnerColumn

------------------------------------------------------------------------

-- WIP
-- TODO Classe HasDefault where
-- default NodeType = Hyperdata
------------------------------------------------------------------------
$(makeAdaptorAndInstance "pNode" ''NodePoly)
$(makeLensesWith abbreviatedFields ''NodePoly)
$(makeAdaptorAndInstance "pNodeSearch" ''NodePolySearch)
$(makeLensesWith abbreviatedFields ''NodePolySearch)

type NodeWrite = NodePoly  (Maybe (Column  PGInt4       ))
                                  (Column  PGInt4       )
                                  (Column  PGInt4       )
                           (Maybe (Column  PGInt4       ))
                                  (Column PGText        )
                           (Maybe (Column  PGTimestamptz))
                                  (Column  PGJsonb      )

type NodeRead = NodePoly  (Column PGInt4        )
                          (Column PGInt4        )
                          (Column PGInt4        )
                          (Column PGInt4        )
                          (Column PGText        )
                          (Column PGTimestamptz )
                          (Column PGJsonb       )


type NodeReadNull = NodePoly  (Column (Nullable PGInt4 ))
                              (Column (Nullable PGInt4 ))
                              (Column (Nullable PGInt4 ))
                              (Column (Nullable PGInt4 ))
                              (Column (Nullable PGText ))
                              (Column (Nullable PGTimestamptz ))
                              (Column (Nullable PGJsonb))

nodeTable :: Table NodeWrite NodeRead
nodeTable = Table "nodes" (pNode Node { _node_id         = optional "id"
                                      , _node_typename   = required "typename"
                                      , _node_userId     = required "user_id"
                                      
                                      , _node_parentId   = optional "parent_id"
                                      , _node_name       = required "name"
                                      , _node_date       = optional "date"
                                      
                                      , _node_hyperdata  = required "hyperdata"
                                      }
                            )

queryNodeTable :: Query NodeRead
queryNodeTable = queryTable nodeTable

------------------------------------------------------------------------
-- | Node(Read|Write)Search is slower than Node(Write|Read) use it
-- for full text search only
type NodeSearchWrite = NodePolySearch  (Maybe (Column  PGInt4              ))
                                  (Column  PGInt4               )
                                  (Column  PGInt4               )
                                  (Column (Nullable PGInt4     ))
                                  (Column (PGText              ))
                                  (Maybe  (Column PGTimestamptz))
                                  (Column  PGJsonb              )
                                  (Maybe (Column PGTSVector))

type NodeSearchRead = NodePolySearch  (Column  PGInt4           )
                          (Column  PGInt4           )
                          (Column  PGInt4           )
                          (Column (Nullable PGInt4 ))
                          (Column (PGText          ))
                          (Column PGTimestamptz     )
                          (Column PGJsonb) 
                          (Column PGTSVector)


type NodeSearchReadNull = NodePolySearch  (Column  (Nullable PGInt4           ))
                              (Column  (Nullable PGInt4           ))
                              (Column  (Nullable PGInt4           ))
                              (Column (Nullable PGInt4 ))
                              (Column (Nullable PGText          ))
                              (Column (Nullable PGTimestamptz     ))
                              (Column (Nullable PGJsonb))
                              (Column (Nullable PGTSVector))


--{-
nodeTableSearch :: Table NodeSearchWrite NodeSearchRead
nodeTableSearch = Table "nodes" (pNodeSearch NodeSearch { _ns_id         = optional "id"
                                      , _ns_typename   = required "typename"
                                      , _ns_userId     = required "user_id"
                                      
                                      , _ns_parentId   = required "parent_id"
                                      , _ns_name       = required "name"
                                      , _ns_date       = optional "date"
                                      
                                      , _ns_hyperdata  = required "hyperdata"
                                      , _ns_search     = optional "search"
                                      }
                            )
--}

queryNodeSearchTable :: Query NodeSearchRead
queryNodeSearchTable = queryTable nodeTableSearch


selectNode :: Column PGInt4 -> Query NodeRead
selectNode id = proc () -> do
    row <- queryNodeTable -< ()
    restrict -< _node_id row .== id
    returnA -< row


runGetNodes :: Query NodeRead -> Cmd err [NodeAny]
runGetNodes = runOpaQuery

------------------------------------------------------------------------
------------------------------------------------------------------------

-- | order by publication date
-- Favorites (Bool), node_ngrams
selectNodesWith :: ParentId     -> Maybe NodeType
                -> Maybe Offset -> Maybe Limit   -> Query NodeRead
selectNodesWith parentId maybeNodeType maybeOffset maybeLimit = 
        --offset' maybeOffset $ limit' maybeLimit $ orderBy (asc (hyperdataDocument_Publication_date . node_hyperdata)) $ selectNodesWith' parentId typeId
  limit' maybeLimit $ offset' maybeOffset
                    $ orderBy (asc _node_id)
                    $ selectNodesWith' parentId maybeNodeType

selectNodesWith' :: ParentId -> Maybe NodeType -> Query NodeRead
selectNodesWith' parentId maybeNodeType = proc () -> do
    node <- (proc () -> do
      row@(Node _ typeId _ parentId' _ _ _) <- queryNodeTable -< ()
      restrict -< parentId' .== (pgInt4 parentId)

      let typeId' = maybe 0 nodeTypeId maybeNodeType

      restrict -< if typeId' > 0
                     then typeId   .== (pgInt4 (typeId' :: Int))
                     else (pgBool True)
      returnA  -< row ) -< ()
    returnA -< node


deleteNode :: Int -> Cmd err Int
deleteNode n = mkCmd $ \conn ->
  fromIntegral <$> runDelete conn nodeTable
                 (\(Node n_id _ _ _ _ _ _) -> n_id .== pgInt4 n)

deleteNodes :: [Int] -> Cmd err Int
deleteNodes ns = mkCmd $ \conn ->
  fromIntegral <$> runDelete conn nodeTable
                   (\(Node n_id _ _ _ _ _ _) -> in_ ((map pgInt4 ns)) n_id)


-- TODO: NodeType should match with `a'
getNodesWith :: JSONB a => Int -> proxy a -> Maybe NodeType
             -> Maybe Offset -> Maybe Limit -> Cmd err [Node a]
getNodesWith parentId _ nodeType maybeOffset maybeLimit =
    runOpaQuery $ selectNodesWith parentId nodeType maybeOffset maybeLimit


-- TODO: Why is the second parameter ignored?
-- TODO: Why not use getNodesWith?
getNodesWithParentId :: Int -> Maybe Text -> Cmd err [NodeAny]
getNodesWithParentId n _ = runOpaQuery $ selectNodesWithParentID n


------------------------------------------------------------------------
getDocumentsV3WithParentId :: Int -> Cmd err [Node HyperdataDocumentV3]
getDocumentsV3WithParentId n = runOpaQuery $ selectNodesWith' n (Just NodeDocument)

-- TODO: merge with getDocumentsWithParentId by having a class IsHyperdataDocument
getDocumentsWithParentId :: Int -> Cmd err [Node HyperdataDocument]
getDocumentsWithParentId n = runOpaQuery $ selectNodesWith' n (Just NodeDocument)

getListsWithParentId :: Int -> Cmd err [Node HyperdataList]
getListsWithParentId n = runOpaQuery $ selectNodesWith' n (Just NodeList)

getCorporaWithParentId :: Int -> Cmd err [Node HyperdataCorpus]
getCorporaWithParentId n = runOpaQuery $ selectNodesWith' n (Just NodeCorpus)

------------------------------------------------------------------------
selectNodesWithParentID :: Int -> Query NodeRead
selectNodesWithParentID n = proc () -> do
    row@(Node _ _ _ parent_id _ _ _) <- queryNodeTable -< ()
    restrict -< parent_id .== (pgInt4 n)
    returnA -< row

selectNodesWithType :: Column PGInt4 -> Query NodeRead
selectNodesWithType type_id = proc () -> do
    row@(Node _ tn _ _ _ _ _) <- queryNodeTable -< ()
    restrict -< tn .== type_id
    returnA -< row

type JSONB = QueryRunnerColumnDefault PGJsonb

getNode :: JSONB a => Int -> proxy a -> Cmd err (Node a)
getNode id _ = do
    fromMaybe (error $ "Node does node exist: " <> show id) . headMay <$> runOpaQuery (limit 1 $ selectNode (pgInt4 id))

getNodesWithType :: Column PGInt4 -> Cmd err [Node HyperdataDocument]
getNodesWithType = runOpaQuery . selectNodesWithType

------------------------------------------------------------------------

------------------------------------------------------------------------
defaultUser :: HyperdataUser
defaultUser = HyperdataUser (Just $ (pack . show) EN)

nodeUserW :: Maybe Name -> Maybe HyperdataUser -> UserId -> NodeWrite
nodeUserW maybeName maybeHyperdata = node NodeUser name user Nothing
  where
    name = maybe "User" identity maybeName
    user = maybe defaultUser identity maybeHyperdata
------------------------------------------------------------------------
defaultFolder :: HyperdataFolder
defaultFolder = HyperdataFolder (Just "Markdown Description")

nodeFolderW :: Maybe Name -> Maybe HyperdataFolder -> ParentId -> UserId -> NodeWrite
nodeFolderW maybeName maybeFolder pid = node NodeFolder name folder (Just pid)
  where
    name   = maybe "Folder" identity maybeName
    folder = maybe defaultFolder identity maybeFolder
------------------------------------------------------------------------
nodeCorpusW :: Maybe Name -> Maybe HyperdataCorpus -> ParentId -> UserId -> NodeWrite
nodeCorpusW maybeName maybeCorpus pId = node NodeCorpus name corpus (Just pId)
  where
    name   = maybe "Corpus" identity maybeName
    corpus = maybe defaultCorpus identity maybeCorpus
                   --------------------------
defaultDocument :: HyperdataDocument
defaultDocument = hyperdataDocument

nodeDocumentW :: Maybe Name -> Maybe HyperdataDocument -> CorpusId -> UserId -> NodeWrite
nodeDocumentW maybeName maybeDocument cId = node NodeDocument name doc (Just cId)
  where
    name = maybe "Document" identity maybeName
    doc  = maybe defaultDocument identity maybeDocument
------------------------------------------------------------------------
defaultAnnuaire :: HyperdataAnnuaire
defaultAnnuaire = HyperdataAnnuaire (Just "Title") (Just "Description")

nodeAnnuaireW :: Maybe Name -> Maybe HyperdataAnnuaire -> ParentId -> UserId -> NodeWrite
nodeAnnuaireW maybeName maybeAnnuaire pId = node NodeAnnuaire name annuaire (Just pId)
  where
    name     = maybe "Annuaire" identity maybeName
    annuaire = maybe defaultAnnuaire identity maybeAnnuaire
                   --------------------------

------------------------------------------------------------------------
arbitraryList :: HyperdataList
arbitraryList = HyperdataList (Just "Preferences")

nodeListW :: Maybe Name -> Maybe HyperdataList -> ParentId -> UserId -> NodeWrite
nodeListW maybeName maybeList pId = node NodeList name list (Just pId)
  where
    name = maybe "Listes" identity maybeName
    list = maybe arbitraryList identity maybeList

------------------------------------------------------------------------
arbitraryGraph :: HyperdataGraph
arbitraryGraph = HyperdataGraph (Just "Preferences")

nodeGraphW :: Maybe Name -> Maybe HyperdataGraph -> ParentId -> UserId -> NodeWrite
nodeGraphW maybeName maybeGraph pId = node NodeGraph name graph (Just pId)
  where
    name = maybe "Graph" identity maybeName
    graph = maybe arbitraryGraph identity maybeGraph

------------------------------------------------------------------------

arbitraryDashboard :: HyperdataDashboard
arbitraryDashboard = HyperdataDashboard (Just "Preferences")

nodeDashboardW :: Maybe Name -> Maybe HyperdataDashboard -> ParentId -> UserId -> NodeWrite
nodeDashboardW maybeName maybeDashboard pId = node NodeDashboard name dashboard (Just pId)
  where
    name = maybe "Dashboard" identity maybeName
    dashboard = maybe arbitraryDashboard identity maybeDashboard



------------------------------------------------------------------------
node :: (ToJSON a, Hyperdata a) => NodeType -> Name -> a -> Maybe ParentId -> UserId -> NodeWrite
node nodeType name hyperData parentId userId = Node Nothing (pgInt4 typeId) (pgInt4 userId) (pgInt4 <$> parentId) (pgStrictText name) Nothing (pgJSONB $ cs $ encode hyperData)
  where
    typeId = nodeTypeId nodeType

                  -------------------------------
insertNodes :: [NodeWrite] -> Cmd err Int64
insertNodes ns = mkCmd $ \conn -> runInsertMany conn nodeTable ns

insertNodesR :: [NodeWrite] -> Cmd err [Int]
insertNodesR ns = mkCmd $ \conn ->
  runInsert_ conn (Insert nodeTable ns (rReturning (\(Node i _ _ _ _ _ __) -> i)) Nothing)

insertNodesWithParent :: Maybe ParentId -> [NodeWrite] -> Cmd err Int64
insertNodesWithParent pid ns = insertNodes (set node_parentId (pgInt4 <$> pid) <$> ns)

insertNodesWithParentR :: Maybe ParentId -> [NodeWrite] -> Cmd err [Int]
insertNodesWithParentR pid ns = insertNodesR (set node_parentId (pgInt4 <$> pid) <$> ns)
------------------------------------------------------------------------
-- TODO Hierachy of Nodes
-- post and get same types Node' and update if changes

{- TODO semantic to achieve
post c uid pid [ Node' NodeCorpus "name" "{}" []
               , Node' NodeFolder "name" "{}" [Node' NodeCorpus "test 2" "" [ Node' NodeDocument "title" "metaData" []
                                                                    , Node' NodeDocument "title" "jsonData" []
                                                                    ]
                                          ]
               ]
-}
------------------------------------------------------------------------

-- TODO
-- currently this function remove the child relation
-- needs a Temporary type between Node' and NodeWriteT
node2table :: UserId -> Maybe ParentId -> Node' -> NodeWrite
node2table uid pid (Node' nt txt v []) = Node Nothing (pgInt4$ nodeTypeId nt) (pgInt4 uid) (fmap pgInt4 pid) (pgStrictText txt) Nothing (pgStrictJSONB $ cs $ encode v)
node2table _ _ (Node' _ _ _ _) = panic "node2table: should not happen, Tree insert not implemented yet"


data Node' = Node' { _n_type :: NodeType
                   , _n_name :: Text
                   , _n_data :: Value
                   , _n_children :: [Node']
                   } deriving (Show)

mkNode :: [NodeWrite] -> Cmd err Int64
mkNode ns = mkCmd $ \conn -> runInsertMany conn nodeTable ns

mkNodeR :: [NodeWrite] -> Cmd err [Int]
mkNodeR ns = mkCmd $ \conn -> runInsertManyReturning conn nodeTable ns (_node_id)

------------------------------------------------------------------------

data NewNode = NewNode { _newNodeId :: Int
                       , _newNodeChildren :: [Int] }

-- | postNode
postNode :: UserId -> Maybe ParentId -> Node' -> Cmd err NewNode
postNode uid pid (Node' nt txt v []) = do
  pids <- mkNodeR [node2table uid pid (Node' nt txt v [])]
  case pids of
    [pid] -> pure $ NewNode pid []
    _ -> panic "postNode: only one pid expected"

postNode uid pid (Node' NodeCorpus txt v ns) = do
  NewNode pid' _ <- postNode uid pid (Node' NodeCorpus txt v [])
  pids  <- mkNodeR (concat $ map (\n -> [childWith uid pid' n]) ns)
  pure $ NewNode pid' pids

postNode uid pid (Node' NodeAnnuaire txt v ns) = do
  NewNode pid' _ <- postNode uid pid (Node' NodeAnnuaire txt v [])
  pids  <- mkNodeR (concat $ map (\n -> [childWith uid pid' n]) ns)
  pure $ NewNode pid' pids
postNode _ _ (Node' _ _ _ _) = panic "TODO: postNode for this type not implemented yet"


childWith :: UserId -> ParentId -> Node' -> NodeWrite
childWith uId pId (Node' NodeDocument txt v []) = node2table uId (Just pId) (Node' NodeDocument txt v [])
childWith uId pId (Node' NodeContact  txt v []) = node2table uId (Just pId) (Node' NodeContact txt v [])
childWith _   _   (Node' _        _   _ _) = panic "This NodeType can not be a child"



mk :: NodeType -> Maybe ParentId -> Text -> Cmd err [Int]
mk nt pId name  = mk' nt userId pId name
  where
    userId = 1

mk' :: NodeType -> UserId -> Maybe ParentId -> Text -> Cmd err [Int]
mk' nt uId pId name  = map fromIntegral <$> insertNodesWithParentR pId [node nt name hd pId uId]
  where
    hd = HyperdataUser . Just . pack $ show EN

type Name = Text

mk'' :: NodeType -> Maybe ParentId -> UserId -> Name -> Cmd err [Int]
mk'' NodeUser Nothing uId name  = mk' NodeUser uId Nothing name
mk'' NodeUser _       _   _     = panic "NodeUser do not have any parent"
mk'' _        Nothing _   _     = panic "NodeType does   have a   parent"
mk'' nt       pId     uId name  = mk' nt uId pId name

mkRoot :: Username -> UserId -> Cmd err [Int]
mkRoot uname uId = case uId > 0 of
               False -> panic "UserId <= 0"
               True  -> mk'' NodeUser Nothing uId uname

mkCorpus :: Maybe Name -> Maybe HyperdataCorpus -> ParentId -> UserId -> Cmd err [Int]
mkCorpus n h p u = insertNodesR [nodeCorpusW n h p u]

getOrMkList :: HasNodeError err => ParentId -> UserId -> Cmd err Int
getOrMkList pId uId =
  defaultList pId
    `catchNodeError`
  (\NoListFound -> maybe (nodeError NoListFound) pure . headMay =<< mkList pId uId)

defaultList :: HasNodeError err => CorpusId -> Cmd err ListId
defaultList cId =
  maybe (nodeError NoListFound) (pure . view node_id) . headMay =<< getListsWithParentId cId

mkList :: HasNodeError err => ParentId -> UserId -> Cmd err [Int]
mkList p u = insertNodesR [nodeListW Nothing Nothing p u]

mkGraph :: ParentId -> UserId -> Cmd err [Int]
mkGraph p u = insertNodesR [nodeGraphW Nothing Nothing p u]

mkDashboard :: ParentId -> UserId -> Cmd err [Int]
mkDashboard p u = insertNodesR [nodeDashboardW Nothing Nothing p u]

mkAnnuaire :: ParentId -> UserId -> Cmd err [Int]
mkAnnuaire p u = insertNodesR [nodeAnnuaireW Nothing Nothing p u]

-- | Default CorpusId Master and ListId Master
