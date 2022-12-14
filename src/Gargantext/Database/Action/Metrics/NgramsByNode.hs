{-|
Module      : Gargantext.Database.Metrics.NgramsByNode
Description : Ngrams by Node user and master
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Ngrams by node enable contextual metrics.

-}

{-# LANGUAGE QuasiQuotes       #-}

module Gargantext.Database.Action.Metrics.NgramsByNode
  where

--import Data.Map.Strict.Patch (PatchMap, Replace, diff)
import Data.HashMap.Strict (HashMap)
import Data.Map (Map)
import Data.Set (Set)
import Data.Text (Text)
import Data.Tuple.Extra (first, second, swap)
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.PostgreSQL.Simple.Types (Values(..), QualifiedIdentifier(..))
import Debug.Trace (trace)
import Gargantext.Core
import Gargantext.API.Ngrams.Types (NgramsTerm(..))
import Gargantext.Data.HashMap.Strict.Utils as HM
import Gargantext.Database.Admin.Types.Node -- (ListId, CorpusId, NodeId)
import Gargantext.Database.Prelude (Cmd, runPGSQuery)
import Gargantext.Database.Schema.Ngrams (ngramsTypeId, NgramsType(..))
import Gargantext.Prelude
import qualified Data.HashMap.Strict as HM
import qualified Data.Map as Map
import qualified Data.Set as Set
import qualified Database.PostgreSQL.Simple as DPS

-- | fst is size of Supra Corpus
--   snd is Texts and size of Occurrences (different docs)
countNodesByNgramsWith :: (NgramsTerm -> NgramsTerm)
                       -> HashMap NgramsTerm (Set NodeId)
                       -> (Double, HashMap NgramsTerm (Double, Set NgramsTerm))
countNodesByNgramsWith f m = (total, m')
  where
    total = fromIntegral $ Set.size $ Set.unions $ HM.elems m
    m'    = HM.map ( swap . second (fromIntegral . Set.size))
          $ groupNodesByNgramsWith f m


groupNodesByNgramsWith :: (NgramsTerm -> NgramsTerm)
                       -> HashMap NgramsTerm (Set NodeId)
                       -> HashMap NgramsTerm (Set NgramsTerm, Set NodeId)
groupNodesByNgramsWith f m =
  HM.fromListWith (<>) $ map (\(t,ns) -> (f t, (Set.singleton t, ns)))
                       $ HM.toList m

------------------------------------------------------------------------
getNodesByNgramsUser ::  HasDBid NodeType
                     => CorpusId
                     -> NgramsType
                     -> Cmd err (HashMap NgramsTerm (Set NodeId))
getNodesByNgramsUser cId nt =
  HM.fromListWith (<>) <$> map (\(n,t) -> (NgramsTerm t, Set.singleton n))
                    <$> selectNgramsByNodeUser cId nt
    where

      selectNgramsByNodeUser :: HasDBid NodeType
                             => CorpusId
                             -> NgramsType
                             -> Cmd err [(NodeId, Text)]
      selectNgramsByNodeUser cId' nt' =
        runPGSQuery queryNgramsByNodeUser
                    ( cId'
                    , toDBid NodeDocument
                    , ngramsTypeId nt'
           --         , 100 :: Int -- limit
           --         , 0   :: Int -- offset
                    )

      queryNgramsByNodeUser :: DPS.Query
      queryNgramsByNodeUser = [sql|
        SELECT nng.node2_id, ng.terms FROM node_node_ngrams nng
          JOIN ngrams ng      ON nng.ngrams_id = ng.id
          JOIN nodes_nodes nn ON nn.node2_id   = nng.node2_id
          JOIN nodes  n       ON nn.node2_id   = n.id
          WHERE nn.node1_id = ?     -- CorpusId
            AND n.typename  = ?     -- toDBid
            AND nng.ngrams_type = ? -- NgramsTypeId
            AND nn.category > 0
            GROUP BY nng.node2_id, ng.terms
            ORDER BY (nng.node2_id, ng.terms) DESC
          --   LIMIT ?
          --  OFFSET ?
        |]
------------------------------------------------------------------------
-- TODO add groups
getOccByNgramsOnlyFast :: HasDBid NodeType
                       => CorpusId
                       -> NgramsType
                       -> [NgramsTerm]
                       -> Cmd err (HashMap NgramsTerm Int)
getOccByNgramsOnlyFast cId nt ngs =
  HM.fromListWith (+) <$> selectNgramsOccurrencesOnlyByNodeUser cId nt ngs


getOccByNgramsOnlyFast_withSample :: HasDBid NodeType
                       => CorpusId
                       -> Int
                       -> NgramsType
                       -> [NgramsTerm]
                       -> Cmd err (HashMap NgramsTerm Int)
getOccByNgramsOnlyFast_withSample cId int nt ngs =
  HM.fromListWith (+) <$> selectNgramsOccurrencesOnlyByNodeUser_withSample cId int nt ngs




getOccByNgramsOnlyFast' :: CorpusId
                       -> ListId
                       -> NgramsType
                       -> [NgramsTerm]
                       -> Cmd err (HashMap NgramsTerm Int)
getOccByNgramsOnlyFast' cId lId nt tms = trace (show (cId, lId)) $
  HM.fromListWith (+) <$> map (second round) <$> run cId lId nt tms

    where
      fields = [QualifiedIdentifier Nothing "text"]

      run :: CorpusId
           -> ListId
           -> NgramsType
           -> [NgramsTerm]
           -> Cmd err [(NgramsTerm, Double)]
      run cId' lId' nt' tms' = fmap (first NgramsTerm) <$> runPGSQuery query
                ( Values fields ((DPS.Only . unNgramsTerm) <$> tms')
                , cId'
                , lId'
                , ngramsTypeId nt'
                )

      query :: DPS.Query
      query = [sql|
        WITH input_rows(terms) AS (?)
        SELECT ng.terms, nng.weight FROM node_node_ngrams nng
          JOIN ngrams ng      ON nng.ngrams_id = ng.id
          JOIN input_rows  ir ON ir.terms      = ng.terms
          WHERE nng.node1_id     = ?   -- CorpusId
            AND nng.node2_id     = ?   -- ListId
            AND nng.ngrams_type  = ?   -- NgramsTypeId
            -- AND nn.category     > 0 -- TODO
            GROUP BY ng.terms, nng.weight
        |]


-- just slower than getOccByNgramsOnlyFast
getOccByNgramsOnlySlow :: HasDBid NodeType
                       => NodeType
                       -> CorpusId
                       -> [ListId]
                       -> NgramsType
                       -> [NgramsTerm]
                       -> Cmd err (HashMap NgramsTerm Int)
getOccByNgramsOnlySlow t cId ls nt ngs =
  HM.map Set.size <$> getScore' t cId ls nt ngs
    where
      getScore' NodeCorpus   = getNodesByNgramsOnlyUser
      getScore' NodeDocument = getNgramsByDocOnlyUser
      getScore' _            = getNodesByNgramsOnlyUser

getOccByNgramsOnlySafe :: HasDBid NodeType
                       => CorpusId
                       -> [ListId]
                       -> NgramsType
                       -> [NgramsTerm]
                       -> Cmd err (HashMap NgramsTerm Int)
getOccByNgramsOnlySafe cId ls nt ngs = do
  printDebug "getOccByNgramsOnlySafe" (cId, nt, length ngs)
  fast <- getOccByNgramsOnlyFast cId nt ngs
  slow <- getOccByNgramsOnlySlow NodeCorpus cId ls nt ngs
  when (fast /= slow) $
    printDebug "getOccByNgramsOnlySafe: difference"
               (HM.difference slow fast, HM.difference fast slow)
               -- diff slow fast :: PatchMap Text (Replace (Maybe Int))
  pure slow


selectNgramsOccurrencesOnlyByNodeUser :: HasDBid NodeType
                                      => CorpusId
                                      -> NgramsType
                                      -> [NgramsTerm]
                                      -> Cmd err [(NgramsTerm, Int)]
selectNgramsOccurrencesOnlyByNodeUser cId nt tms =
  fmap (first NgramsTerm) <$>
  runPGSQuery queryNgramsOccurrencesOnlyByNodeUser
                ( Values fields ((DPS.Only . unNgramsTerm) <$> tms)
                , cId
                , toDBid NodeDocument
                , ngramsTypeId nt
                )
    where
      fields = [QualifiedIdentifier Nothing "text"]



-- same as queryNgramsOnlyByNodeUser but using COUNT on the node ids.
-- Question: with the grouping is the result exactly the same (since Set NodeId for 
-- equivalent ngrams intersections are not empty)
queryNgramsOccurrencesOnlyByNodeUser :: DPS.Query
queryNgramsOccurrencesOnlyByNodeUser = [sql|
  WITH input_rows(terms) AS (?)
  SELECT ng.terms, COUNT(nng.node2_id) FROM node_node_ngrams nng
    JOIN ngrams ng      ON nng.ngrams_id = ng.id
    JOIN input_rows  ir ON ir.terms      = ng.terms
    JOIN nodes_nodes nn ON nn.node2_id   = nng.node2_id
    JOIN nodes  n       ON nn.node2_id   = n.id
    WHERE nn.node1_id     = ? -- CorpusId
      AND n.typename      = ? -- toDBid
      AND nng.ngrams_type = ? -- NgramsTypeId
      AND nn.category     > 0
      GROUP BY nng.node2_id, ng.terms
  |]


selectNgramsOccurrencesOnlyByNodeUser_withSample :: HasDBid NodeType
                                      => CorpusId
                                      -> Int
                                      -> NgramsType
                                      -> [NgramsTerm]
                                      -> Cmd err [(NgramsTerm, Int)]
selectNgramsOccurrencesOnlyByNodeUser_withSample cId int nt tms =
  fmap (first NgramsTerm) <$>
  runPGSQuery queryNgramsOccurrencesOnlyByNodeUser_withSample
                ( int
                , toDBid NodeDocument
                , cId
                , Values fields ((DPS.Only . unNgramsTerm) <$> tms)
                , cId
                , ngramsTypeId nt
                )
    where
      fields = [QualifiedIdentifier Nothing "text"]

queryNgramsOccurrencesOnlyByNodeUser_withSample :: DPS.Query
queryNgramsOccurrencesOnlyByNodeUser_withSample = [sql|
  WITH nodes_sample AS (SELECT id FROM nodes n TABLESAMPLE SYSTEM_ROWS (?)
                          JOIN nodes_nodes nn ON n.id = nn.node2_id
                            WHERE n.typename  = ?
                            AND nn.node1_id = ?),
       input_rows(terms) AS (?)
  SELECT ng.terms, COUNT(nng.node2_id) FROM node_node_ngrams nng
    JOIN ngrams ng      ON nng.ngrams_id = ng.id
    JOIN input_rows  ir ON ir.terms      = ng.terms
    JOIN nodes_nodes nn ON nn.node2_id   = nng.node2_id
    JOIN nodes_sample n ON nn.node2_id   = n.id
    WHERE nn.node1_id     = ? -- CorpusId
      AND nng.ngrams_type = ? -- NgramsTypeId
      AND nn.category     > 0
      GROUP BY nng.node2_id, ng.terms
  |]



queryNgramsOccurrencesOnlyByNodeUser' :: DPS.Query
queryNgramsOccurrencesOnlyByNodeUser' = [sql|
  WITH input_rows(terms) AS (?)
  SELECT ng.terms, COUNT(nng.node2_id) FROM node_node_ngrams nng
    JOIN ngrams ng      ON nng.ngrams_id = ng.id
    JOIN input_rows  ir ON ir.terms      = ng.terms
    JOIN nodes_nodes nn ON nn.node2_id   = nng.node2_id
    JOIN nodes  n       ON nn.node2_id   = n.id
    WHERE nn.node1_id     = ? -- CorpusId
      AND n.typename      = ? -- toDBid
      AND nng.ngrams_type = ? -- NgramsTypeId
      AND nn.category     > 0
      GROUP BY nng.node2_id, ng.terms
  |]

------------------------------------------------------------------------
getNodesByNgramsOnlyUser :: HasDBid NodeType
                         => CorpusId
                         -> [ListId]
                         -> NgramsType
                         -> [NgramsTerm]
                         -> Cmd err (HashMap NgramsTerm (Set NodeId))
getNodesByNgramsOnlyUser cId ls nt ngs =
     HM.unionsWith        (<>)
   . map (HM.fromListWith (<>)
   . map (second Set.singleton))
  <$> mapM (selectNgramsOnlyByNodeUser cId ls nt)
           (splitEvery 1000 ngs)


getNgramsByNodeOnlyUser :: HasDBid NodeType
                        => NodeId
                        -> [ListId]
                        -> NgramsType
                        -> [NgramsTerm]
                        -> Cmd err (Map NodeId (Set NgramsTerm))
getNgramsByNodeOnlyUser cId ls nt ngs =
     Map.unionsWith         (<>)
   . map ( Map.fromListWith (<>)
         . map (second Set.singleton)
         )
   . map (map swap)
  <$> mapM (selectNgramsOnlyByNodeUser cId ls nt)
           (splitEvery 1000 ngs)

------------------------------------------------------------------------
selectNgramsOnlyByNodeUser :: HasDBid NodeType
                           => CorpusId
                           -> [ListId]
                           -> NgramsType
                           -> [NgramsTerm]
                           -> Cmd err [(NgramsTerm, NodeId)]
selectNgramsOnlyByNodeUser cId ls nt tms =
  fmap (first NgramsTerm) <$>
  runPGSQuery queryNgramsOnlyByNodeUser
                ( Values fields ((DPS.Only . unNgramsTerm) <$> tms)
                , Values [QualifiedIdentifier Nothing "int4"] 
                         (DPS.Only <$> (map (\(NodeId n) -> n) ls))
                , cId
                , toDBid NodeDocument
                , ngramsTypeId nt
                )
    where
      fields = [QualifiedIdentifier Nothing "text"]

queryNgramsOnlyByNodeUser :: DPS.Query
queryNgramsOnlyByNodeUser = [sql|
  WITH input_rows(terms) AS (?),
       input_list(id)    AS (?)
  SELECT ng.terms, nng.node2_id FROM node_node_ngrams nng
    JOIN ngrams ng      ON nng.ngrams_id = ng.id
    JOIN input_rows  ir ON ir.terms      = ng.terms
    JOIN input_list  il ON il.id         = nng.node1_id
    JOIN nodes_nodes nn ON nn.node2_id   = nng.node2_id
    JOIN nodes  n       ON nn.node2_id   = n.id
    WHERE nn.node1_id     = ? -- CorpusId
      AND n.typename      = ? -- toDBid
      AND nng.ngrams_type = ? -- NgramsTypeId
      AND nn.category     > 0
      GROUP BY ng.terms, nng.node2_id
  |]


selectNgramsOnlyByNodeUser' :: HasDBid NodeType
                            => CorpusId
                            -> [ListId]
                            -> NgramsType
                            -> [Text]
                            -> Cmd err [(Text, Int)]
selectNgramsOnlyByNodeUser' cId ls nt tms =
  runPGSQuery queryNgramsOnlyByNodeUser
                ( Values fields (DPS.Only <$> tms)
                , Values [QualifiedIdentifier Nothing "int4"]
                         (DPS.Only <$> (map (\(NodeId n) -> n) ls))
                , cId
                , toDBid NodeDocument
                , ngramsTypeId nt
                )
    where
      fields = [QualifiedIdentifier Nothing "text"]

queryNgramsOnlyByNodeUser' :: DPS.Query
queryNgramsOnlyByNodeUser' = [sql|
  WITH input_rows(terms) AS (?),
       input_list(id)    AS (?)
  SELECT ng.terms, nng.weight FROM node_node_ngrams nng
    JOIN ngrams ng      ON nng.ngrams_id = ng.id
    JOIN input_rows  ir ON ir.terms      = ng.terms
    JOIN input_list  il ON il.id         = nng.node2_id
    WHERE nng.node1_id     = ? -- CorpusId
      AND nng.ngrams_type = ? -- NgramsTypeId
      -- AND nn.category     > 0
      GROUP BY ng.terms, nng.weight
  |]


getNgramsByDocOnlyUser :: DocId
                       -> [ListId]
                       -> NgramsType
                       -> [NgramsTerm]
                       -> Cmd err (HashMap NgramsTerm (Set NodeId))
getNgramsByDocOnlyUser cId ls nt ngs =
  HM.unionsWith (<>)
  . map (HM.fromListWith (<>) . map (second Set.singleton))
  <$> mapM (selectNgramsOnlyByDocUser cId ls nt) (splitEvery 1000 ngs)


selectNgramsOnlyByDocUser :: DocId
                          -> [ListId]
                          -> NgramsType
                          -> [NgramsTerm]
                          -> Cmd err [(NgramsTerm, NodeId)]
selectNgramsOnlyByDocUser dId ls nt tms =
  fmap (first NgramsTerm) <$>
  runPGSQuery queryNgramsOnlyByDocUser
                ( Values fields ((DPS.Only . unNgramsTerm) <$> tms)
                , Values [QualifiedIdentifier Nothing "int4"]
                         (DPS.Only <$> (map (\(NodeId n) -> n) ls))
                , dId
                , ngramsTypeId nt
                )
    where
      fields = [QualifiedIdentifier Nothing "text"]


queryNgramsOnlyByDocUser :: DPS.Query
queryNgramsOnlyByDocUser = [sql|
  WITH input_rows(terms) AS (?),
       input_list(id)    AS (?)
  SELECT ng.terms, nng.node2_id FROM node_node_ngrams nng
    JOIN ngrams ng      ON nng.ngrams_id = ng.id
    JOIN input_rows  ir ON ir.terms      = ng.terms
    JOIN input_list  il ON il.id         = nng.node1_id
    WHERE nng.node2_id     = ? -- DocId
      AND nng.ngrams_type = ? -- NgramsTypeId
      GROUP BY ng.terms, nng.node2_id
  |]

------------------------------------------------------------------------
-- | TODO filter by language, database, any social field
getNodesByNgramsMaster :: HasDBid NodeType
                       =>  UserCorpusId -> MasterCorpusId -> Cmd err (HashMap Text (Set NodeId))
getNodesByNgramsMaster ucId mcId = unionsWith (<>)
                                 . map (HM.fromListWith (<>) . map (\(n,t) -> (t, Set.singleton n)))
                                 -- . takeWhile (not . List.null)
                                 -- . takeWhile (\l -> List.length l > 3)
                                <$> mapM (selectNgramsByNodeMaster 1000 ucId mcId) [0,500..10000]

selectNgramsByNodeMaster :: HasDBid NodeType
                         => Int
                         -> UserCorpusId
                         -> MasterCorpusId
                         -> Int
                         -> Cmd err [(NodeId, Text)]
selectNgramsByNodeMaster n ucId mcId p = runPGSQuery
                               queryNgramsByNodeMaster'
                                 ( ucId
                                 , ngramsTypeId NgramsTerms
                                 , toDBid   NodeDocument
                                 , p
                                 , toDBid   NodeDocument
                                 , p
                                 , n
                                 , mcId
                                 , toDBid   NodeDocument
                                 , ngramsTypeId NgramsTerms
                                 )

-- | TODO fix node_node_ngrams relation
queryNgramsByNodeMaster' :: DPS.Query
queryNgramsByNodeMaster' = [sql|
  WITH nodesByNgramsUser AS (

  SELECT n.id, ng.terms FROM nodes n
    JOIN nodes_nodes  nn  ON n.id = nn.node2_id
    JOIN node_node_ngrams nng ON nng.node2_id   = n.id
    JOIN ngrams       ng  ON nng.ngrams_id = ng.id
    WHERE nn.node1_id     = ?   -- UserCorpusId
      -- AND n.typename   = ?  -- toDBid
      AND nng.ngrams_type = ? -- NgramsTypeId
      AND nn.category > 0
      AND node_pos(n.id,?) >= ?
      AND node_pos(n.id,?) <  ?
    GROUP BY n.id, ng.terms

    ),

  nodesByNgramsMaster AS (

  SELECT n.id, ng.terms FROM nodes n TABLESAMPLE SYSTEM_ROWS(?)
    JOIN node_node_ngrams nng  ON n.id  = nng.node2_id
    JOIN ngrams       ng   ON ng.id = nng.ngrams_id

    WHERE n.parent_id  = ?     -- Master Corpus toDBid
      AND n.typename   = ?     -- toDBid
      AND nng.ngrams_type = ? -- NgramsTypeId
    GROUP BY n.id, ng.terms
    )

  SELECT m.id, m.terms FROM nodesByNgramsMaster m
    RIGHT JOIN nodesByNgramsUser u ON u.id = m.id
  |]
