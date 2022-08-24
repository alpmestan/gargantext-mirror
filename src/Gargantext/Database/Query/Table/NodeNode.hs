{-| Module      : Gargantext.Database.Select.Table.NodeNode
Description : 
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Here is a longer description of this module, containing some
commentary with @some markup@.
-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE Arrows                 #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE QuasiQuotes            #-}
{-# LANGUAGE TemplateHaskell        #-}

module Gargantext.Database.Query.Table.NodeNode
  ( module Gargantext.Database.Schema.NodeNode
  , deleteNodeNode
  , getNodeNode
  , insertNodeNode
  , nodeNodesCategory
  , nodeNodesScore
  , queryNodeNodeTable
  , selectDocNodes
  , selectDocs
  , selectDocsDates
  , selectPublicNodes
  )
  where

import Control.Arrow (returnA)
import Control.Lens ((^.), view)
import Data.Text (Text, splitOn)
import Data.Maybe (catMaybes)
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.PostgreSQL.Simple.Types (Values(..), QualifiedIdentifier(..))
import Gargantext.Core
import Gargantext.Core.Types
import Gargantext.Database.Admin.Types.Hyperdata
import Gargantext.Database.Prelude
import Gargantext.Database.Schema.Node
import Gargantext.Database.Schema.NodeNode
import Gargantext.Prelude
import Opaleye
import qualified Database.PostgreSQL.Simple as PGS
import qualified Opaleye as O

queryNodeNodeTable :: Select NodeNodeRead
queryNodeNodeTable = selectTable nodeNodeTable

-- | not optimized (get all ngrams without filters)
_nodesNodes :: Cmd err [NodeNode]
_nodesNodes = runOpaQuery queryNodeNodeTable

------------------------------------------------------------------------
-- | Basic NodeNode tools
getNodeNode :: NodeId -> Cmd err [NodeNode]
getNodeNode n = runOpaQuery (selectNodeNode $ pgNodeId n)
  where
    selectNodeNode :: Column SqlInt4 -> Select NodeNodeRead
    selectNodeNode n' = proc () -> do
      ns <- queryNodeNodeTable -< ()
      restrict -< _nn_node1_id ns .== n'
      returnA -< ns

------------------------------------------------------------------------
-- TODO (refactor with Children)
{-
getNodeNodeWith :: NodeId -> proxy a -> Maybe NodeType -> Cmd err [a]
getNodeNodeWith pId _ maybeNodeType = runOpaQuery query
  where
    query = selectChildren pId maybeNodeType

    selectChildren :: ParentId
                   -> Maybe NodeType
                   -> Select NodeRead
    selectChildren parentId maybeNodeType = proc () -> do
        row@(Node nId typeName _ parent_id _ _ _) <- queryNodeTable -< ()
        (NodeNode _ n1id n2id _ _) <- queryNodeNodeTable -< ()

        let nodeType = maybe 0 toDBid maybeNodeType
        restrict -< typeName  .== sqlInt4 nodeType

        restrict -< (.||) (parent_id .== (pgNodeId parentId))
                          ( (.&&) (n1id .== pgNodeId parentId)
                                  (n2id .== nId))
        returnA -< row
-}

------------------------------------------------------------------------
insertNodeNode :: [NodeNode] -> Cmd err Int
insertNodeNode ns = mkCmd $ \conn -> fromIntegral <$> (runInsert_ conn
                          $ Insert nodeNodeTable ns' rCount (Just DoNothing))
  where
    ns' :: [NodeNodeWrite]
    ns' = map (\(NodeNode n1 n2 x y)
                -> NodeNode (pgNodeId n1)
                            (pgNodeId n2)
                            (sqlDouble <$> x)
                            (sqlInt4   <$> y)
              ) ns



------------------------------------------------------------------------
type Node1_Id = NodeId
type Node2_Id = NodeId

deleteNodeNode :: Node1_Id -> Node2_Id -> Cmd err Int
deleteNodeNode n1 n2 = mkCmd $ \conn ->
  fromIntegral <$> runDelete_ conn
                  (Delete nodeNodeTable
                          (\(NodeNode n1_id n2_id _ _) -> n1_id .== pgNodeId n1
                                                      .&& n2_id .== pgNodeId n2
                          )
                          rCount
                  )

------------------------------------------------------------------------
-- | Favorite management
_nodeNodeCategory :: CorpusId -> DocId -> Int -> Cmd err [Int]
_nodeNodeCategory cId dId c = map (\(PGS.Only a) -> a) <$> runPGSQuery favQuery (c,cId,dId)
  where
    favQuery :: PGS.Query
    favQuery = [sql|UPDATE nodes_nodes SET category = ?
               WHERE node1_id = ? AND node2_id = ?
               RETURNING node2_id;
               |]

nodeNodesCategory :: [(CorpusId, DocId, Int)] -> Cmd err [Int]
nodeNodesCategory inputData = map (\(PGS.Only a) -> a)
                            <$> runPGSQuery catQuery (PGS.Only $ Values fields inputData)
  where
    fields = map (\t-> QualifiedIdentifier Nothing t) ["int4","int4","int4"]
    catQuery :: PGS.Query
    catQuery = [sql| UPDATE nodes_nodes as nn0
                      SET category = nn1.category
                       FROM (?) as nn1(node1_id,node2_id,category)
                       WHERE nn0.node1_id = nn1.node1_id
                       AND   nn0.node2_id = nn1.node2_id
                       RETURNING nn1.node2_id
                  |]

------------------------------------------------------------------------
-- | Score management
_nodeNodeScore :: CorpusId -> DocId -> Int -> Cmd err [Int]
_nodeNodeScore cId dId c = map (\(PGS.Only a) -> a) <$> runPGSQuery scoreQuery (c,cId,dId)
  where
    scoreQuery :: PGS.Query
    scoreQuery = [sql|UPDATE nodes_nodes SET score = ?
                  WHERE node1_id = ? AND node2_id = ?
                  RETURNING node2_id;
                  |]

nodeNodesScore :: [(CorpusId, DocId, Int)] -> Cmd err [Int]
nodeNodesScore inputData = map (\(PGS.Only a) -> a)
                            <$> runPGSQuery catScore (PGS.Only $ Values fields inputData)
  where
    fields = map (\t-> QualifiedIdentifier Nothing t) ["int4","int4","int4"]
    catScore :: PGS.Query
    catScore = [sql| UPDATE nodes_nodes as nn0
                      SET score = nn1.score
                       FROM (?) as nn1(node1_id, node2_id, score)
                       WHERE nn0.node1_id = nn1.node1_id
                       AND   nn0.node2_id = nn1.node2_id
                       RETURNING nn1.node2_id
                  |]

------------------------------------------------------------------------
_selectCountDocs :: HasDBid NodeType => CorpusId -> Cmd err Int
_selectCountDocs cId = runCountOpaQuery (queryCountDocs cId)
  where
    queryCountDocs cId' = proc () -> do
      (n, nn) <- joinInCorpus -< ()
      restrict -< nn^.nn_node1_id  .== (toNullable $ pgNodeId cId')
      restrict -< nn^.nn_category  .>= (toNullable $ sqlInt4 1)
      restrict -< n^.node_typename .== (sqlInt4 $ toDBid NodeDocument)
      returnA -< n




-- | TODO use UTCTime fast
selectDocsDates :: HasDBid NodeType => CorpusId -> Cmd err [Text]
selectDocsDates cId =  map (head' "selectDocsDates" . splitOn "-")
                   <$> catMaybes
                   <$> map (view hd_publication_date)
                   <$> selectDocs cId

selectDocs :: HasDBid NodeType => CorpusId -> Cmd err [HyperdataDocument]
selectDocs cId = runOpaQuery (queryDocs cId)

queryDocs :: HasDBid NodeType => CorpusId -> O.Select (Column SqlJsonb)
queryDocs cId = proc () -> do
  (n, nn) <- joinInCorpus -< ()
  restrict -< nn^.nn_node1_id  .== (toNullable $ pgNodeId cId)
  restrict -< nn^.nn_category  .>= (toNullable $ sqlInt4 1)
  restrict -< n^.node_typename .== (sqlInt4 $ toDBid NodeDocument)
  returnA -< view (node_hyperdata) n

selectDocNodes :: HasDBid NodeType =>CorpusId -> Cmd err [Node HyperdataDocument]
selectDocNodes cId = runOpaQuery (queryDocNodes cId)

queryDocNodes :: HasDBid NodeType =>CorpusId -> O.Select NodeRead
queryDocNodes cId = proc () -> do
  (n, nn) <- joinInCorpus -< ()
  restrict -< nn^.nn_node1_id  .== (toNullable $ pgNodeId cId)
  restrict -< nn^.nn_category  .>= (toNullable $ sqlInt4 1)
  restrict -< n^.node_typename .== (sqlInt4 $ toDBid NodeDocument)
  returnA -<  n

joinInCorpus :: O.Select (NodeRead, NodeNodeReadNull)
joinInCorpus = leftJoin queryNodeTable queryNodeNodeTable cond
  where
    cond :: (NodeRead, NodeNodeRead) -> Column SqlBool
    cond (n, nn) = nn^.nn_node2_id .== (view node_id n)

_joinOn1 :: O.Select (NodeRead, NodeNodeReadNull)
_joinOn1 = leftJoin queryNodeTable queryNodeNodeTable cond
  where
    cond :: (NodeRead, NodeNodeRead) -> Column SqlBool
    cond (n, nn) = nn^.nn_node1_id .== n^.node_id


------------------------------------------------------------------------
selectPublicNodes :: HasDBid NodeType => (Hyperdata a, DefaultFromField SqlJsonb a)
                  => Cmd err [(Node a, Maybe Int)]
selectPublicNodes = runOpaQuery (queryWithType NodeFolderPublic)

queryWithType :: HasDBid NodeType
              => NodeType
              -> O.Select (NodeRead, Column (Nullable SqlInt4))
queryWithType nt = proc () -> do
  (n, nn) <- node_NodeNode -< ()
  restrict -< n^.node_typename .== (sqlInt4 $ toDBid nt)
  returnA  -<  (n, nn^.nn_node2_id)

node_NodeNode :: O.Select (NodeRead, NodeNodeReadNull)
node_NodeNode = leftJoin queryNodeTable queryNodeNodeTable cond
  where
    cond :: (NodeRead, NodeNodeRead) -> Column SqlBool
    cond (n, nn) = nn^.nn_node1_id .== n^.node_id



