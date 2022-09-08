{-|
Module      : Gargantext.Core.NodeStory
Description : Node API generation
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

A Node Story is a Map between NodeId and an Archive (with state,
version and history) for that node.

Couple of words on how this is implemented.

First version used files which stored Archive for each NodeId in a
separate .cbor file.

For performance reasons, it is rewritten to use the DB.

The table `node_stories` contains two columns: `node_id` and
`archive`.

Next, it was observed that `a_history` in `Archive` takes much
space. So a new table was created, `node_story_archive_history` with
columns: `node_id`, `ngrams_type_id`, `patch`. This is because each
history item is in fact a map from `NgramsType` to `NgramsTablePatch`
(see the `NgramsStatePatch'` type).

Moreover, since in ~G.A.Ngrams.commitStatePatch~ we use current state
only, with only recent history items, I concluded that it is not
necessary to load whole history into memory. Instead, it is kept in DB
(history is immutable) and only recent changes are added to
`a_history`. Then that record is cleared whenever `Archive` is saved.

Please note that

TODO:
- remove
- filter
- charger les listes
-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE ConstraintKinds   #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell   #-}

module Gargantext.Core.NodeStory
  ( HasNodeStory
  , HasNodeStoryEnv
  , hasNodeStory
  , HasNodeStoryVar
  , hasNodeStoryVar
  , HasNodeStorySaver
  , hasNodeStorySaver
  , NodeStory(..)
  , NgramsStatePatch'
  , NodeListStory
  , initNodeListStoryMock
  , NodeStoryEnv(..)
  , initNodeStory
  , nse_getter
  , nse_saver
  , nse_var
  , unNodeStory
  , getNodeArchiveHistory
  , Archive(..)
  , initArchive
  , insertArchiveList
  , deleteArchiveList
  , updateArchiveList
  , a_history
  , a_state
  , a_version
  , nodeExists
  , runPGSQuery
  , runPGSAdvisoryLock
  , runPGSAdvisoryUnlock
  , runPGSAdvisoryXactLock
  , getNodesIdWithType
  , readNodeStoryEnv
  , upsertNodeStories
  , getNodeStory
  , nodeStoriesQuery
  , currentVersion )
where

-- import Debug.Trace (traceShow)
import Control.Debounce (mkDebounce, defaultDebounceSettings, debounceFreq, debounceAction)
import Codec.Serialise.Class
import Control.Concurrent (MVar(), newMVar, modifyMVar_)
import Control.Exception (catch, throw, SomeException(..))
import Control.Lens (makeLenses, Getter, (^.), (.~), (%~), _Just, at, traverse, view)
import Control.Monad.Except
import Control.Monad.Reader
import Data.Aeson hiding ((.=), decode)
import Data.ByteString.Char8 (hPutStrLn)
import Data.Map.Strict (Map)
import Data.Maybe (catMaybes)
import Data.Monoid
import Data.Pool (Pool, withResource)
import Data.Semigroup
import Database.PostgreSQL.Simple.SqlQQ (sql)
import Database.PostgreSQL.Simple.FromField (FromField(fromField), fromJSONField)
import Data.Profunctor.Product.TH (makeAdaptorAndInstance)
import GHC.Generics (Generic)
import Gargantext.API.Ngrams.Types
import Gargantext.Core.Types (ListId, NodeId(..), NodeType)
import Gargantext.Core.Utils.Prefix (unPrefix)
import Gargantext.Database.Prelude (CmdM', HasConnectionPool(..), HasConfig)
import Gargantext.Database.Query.Table.Node.Error (HasNodeError())
import Gargantext.Prelude
import Opaleye (DefaultFromField(..), SqlJsonb, fromPGSFromField)
import System.IO (stderr)
import qualified Data.Map.Strict                        as Map
import qualified Data.Map.Strict.Patch                  as PM
import qualified Data.Set as Set
import qualified Database.PostgreSQL.Simple as PGS
import qualified Gargantext.Database.Query.Table.Ngrams as TableNgrams

------------------------------------------------------------------------
data NodeStoryEnv = NodeStoryEnv
  { _nse_var    :: !(MVar NodeListStory)
  , _nse_saver  :: !(IO ())
  , _nse_getter :: [NodeId] -> IO (MVar NodeListStory)
  --, _nse_cleaner :: !(IO ()) -- every 12 hours: cleans the repos of unused NodeStories
  -- , _nse_lock  :: !FileLock -- TODO (it depends on the option: if with database or file only)
  }
  deriving (Generic)

type HasNodeStory env err m = ( CmdM' env err m
                              , MonadReader env m
                              , MonadError  err m
                              , HasNodeStoryEnv env
                              , HasConfig env
                              , HasConnectionPool env
                              , HasNodeError err
                              )

class (HasNodeStoryVar env, HasNodeStorySaver env)
  => HasNodeStoryEnv env where
    hasNodeStory :: Getter env NodeStoryEnv

class HasNodeStoryVar env where
  hasNodeStoryVar :: Getter env ([NodeId] -> IO (MVar NodeListStory))

class HasNodeStorySaver env where
  hasNodeStorySaver :: Getter env (IO ())

------------------------------------------------------------------------

{- | Node Story for each NodeType where the Key of the Map is NodeId
  TODO : generalize for any NodeType, let's start with NodeList which
  is implemented already
-}
newtype NodeStory s p = NodeStory { _unNodeStory :: Map NodeId (Archive s p) }
  deriving (Generic, Show)

instance (FromJSON s, FromJSON p) => FromJSON (NodeStory s p)
instance (ToJSON s, ToJSON p) => ToJSON (NodeStory s p)
instance (Serialise s, Serialise p) => Serialise (NodeStory s p)

data Archive s p = Archive
  { _a_version           :: !Version
  , _a_state             :: !s
  , _a_history           :: ![p]
    -- first patch in the list is the most recent
    -- We use `take` in `commitStatePatch`, that's why.

    -- History is immutable, we just insert things on top of existing
    -- list.

    -- We don't need to store the whole history in memory, this
    -- structure holds only recent history, the one that will be
    -- inserted to the DB.
  }
  deriving (Generic, Show)

instance (Serialise s, Serialise p) => Serialise (Archive s p)


type NodeListStory     = NodeStory NgramsState' NgramsStatePatch'

type NgramsState'      = Map       TableNgrams.NgramsType NgramsTableMap
type NgramsStatePatch' = PatchMap  TableNgrams.NgramsType NgramsTablePatch
instance Serialise NgramsStatePatch'
instance FromField (Archive NgramsState' NgramsStatePatch')
  where
    fromField = fromJSONField
instance DefaultFromField SqlJsonb (Archive NgramsState' NgramsStatePatch')
  where
    defaultFromField = fromPGSFromField

-- | Combine `NgramsState'`. This is because the structure is (Map
-- NgramsType (Map ...)) and the default `(<>)` operator is
-- left-biased
-- (https://hackage.haskell.org/package/containers-0.6.6/docs/Data-Map-Internal.html#v:union)
combineState :: NgramsState' -> NgramsState' -> NgramsState'
combineState = Map.unionWith (<>)

instance (Semigroup s, Semigroup p) => Semigroup (Archive s p) where
  (<>) (Archive { _a_history = p }) (Archive { _a_version = v'
                                             , _a_state = s'
                                             , _a_history = p' }) =
    Archive { _a_version = v'
            , _a_state = s'
            , _a_history = p' <> p }
instance (Monoid s, Semigroup p) => Monoid (Archive s p) where
  mempty = Archive { _a_version = 0
                   , _a_state = mempty
                   , _a_history = [] }
instance (FromJSON s, FromJSON p) => FromJSON (Archive s p) where
  parseJSON = genericParseJSON $ unPrefix "_a_"
instance (ToJSON s, ToJSON p) => ToJSON (Archive s p) where
  toJSON     = genericToJSON     $ unPrefix "_a_"
  toEncoding = genericToEncoding $ unPrefix "_a_"

------------------------------------------------------------------------
initNodeStory :: (Monoid s, Semigroup p) => NodeId -> NodeStory s p
initNodeStory ni = NodeStory $ Map.singleton ni initArchive

initArchive :: (Monoid s, Semigroup p) => Archive s p
initArchive = mempty

initNodeListStoryMock :: NodeListStory
initNodeListStoryMock = NodeStory $ Map.singleton nodeListId archive
  where
    nodeListId = 0
    archive = Archive { _a_version = 0
                      , _a_state = ngramsTableMap
                      , _a_history = [] }
    ngramsTableMap = Map.singleton TableNgrams.NgramsTerms
                   $ Map.fromList
                   [ (n ^. ne_ngrams, ngramsElementToRepo n)
                   | n <- mockTable ^. _NgramsTable
                   ]

------------------------------------------------------------------------


------------------------------------------------------------------------
-- | Lenses at the bottom of the file because Template Haskell would reorder order of execution in others cases
makeLenses ''NodeStoryEnv
makeLenses ''NodeStory
makeLenses ''Archive

-----------------------------------------


data NodeStoryPoly nid v ngtid ngid nre =
  NodeStoryDB { node_id             :: nid
              , version             :: v
              , ngrams_type_id      :: ngtid
              , ngrams_id           :: ngid
              , ngrams_repo_element :: nre }
  deriving (Eq)

data NodeStoryArchivePoly nid a =
  NodeStoryArchiveDB { a_node_id :: nid
                     , archive :: a }
  deriving (Eq)

$(makeAdaptorAndInstance "pNodeStory" ''NodeStoryPoly)
$(makeAdaptorAndInstance "pNodeArchiveStory" ''NodeStoryArchivePoly)

-- type NodeStoryWrite = NodeStoryPoly (Column SqlInt4) (Column SqlInt4) (Column SqlInt4) (Column SqlInt4) (Column SqlJsonb)
-- type NodeStoryRead = NodeStoryPoly (Column SqlInt4) (Column SqlInt4) (Column SqlInt4) (Column SqlInt4) (Column SqlJsonb)

-- type NodeStoryArchiveWrite = NodeStoryArchivePoly (Column SqlInt4) (Column SqlJsonb)
-- type NodeStoryArchiveRead = NodeStoryArchivePoly (Column SqlInt4) (Column SqlJsonb)

type ArchiveList = Archive NgramsState' NgramsStatePatch'

-- DB stuff

runPGSExecute :: (PGS.ToRow q) => PGS.Connection -> PGS.Query -> q -> IO Int64
runPGSExecute c qs a = catch (PGS.execute c qs a) printError
  where
    printError (SomeException e) = do
      --q' <- PGS.formatQuery c qs a
      --hPutStrLn stderr q'
      throw (SomeException e)

runPGSExecuteMany :: (PGS.ToRow q) => PGS.Connection -> PGS.Query -> [q] -> IO Int64
runPGSExecuteMany c qs a = catch (PGS.executeMany c qs a) printError
  where
    printError (SomeException e) = do
      --q' <- PGS.formatQuery c qs a
      --hPutStrLn stderr q'
      throw (SomeException e)

runPGSQuery :: (PGS.FromRow r, PGS.ToRow q) => PGS.Connection -> PGS.Query -> q -> IO [r]
runPGSQuery c q a = catch (PGS.query c q a) printError
  where
    printError (SomeException e) = do
      q' <- PGS.formatQuery c q a
      hPutStrLn stderr q'
      throw (SomeException e)

runPGSAdvisoryLock :: PGS.Connection -> Int -> IO ()
runPGSAdvisoryLock c id = do
  _ <- runPGSQuery c [sql| SELECT pg_advisory_lock(?) |] (PGS.Only id) :: IO [PGS.Only ()]
  pure ()

runPGSAdvisoryUnlock :: PGS.Connection -> Int -> IO ()
runPGSAdvisoryUnlock c id = do
  _ <- runPGSQuery c [sql| SELECT pg_advisory_unlock(?) |] (PGS.Only id) :: IO [PGS.Only Bool]
  pure ()

runPGSAdvisoryXactLock :: PGS.Connection -> Int -> IO ()
runPGSAdvisoryXactLock c id = do
  _ <- runPGSQuery c [sql| SELECT pg_advisory_xact_lock(?) |] (PGS.Only id) :: IO [PGS.Only ()]
  pure ()

nodeExists :: PGS.Connection -> NodeId -> IO Bool
nodeExists c nId = (== [PGS.Only True])
  <$> runPGSQuery c [sql| SELECT true FROM nodes WHERE id = ? LIMIT 1 |] (PGS.Only nId)

getNodesIdWithType :: PGS.Connection -> NodeType -> IO [NodeId]
getNodesIdWithType c nt = do
  ns <- runPGSQuery c query (PGS.Only nt)
  pure $ map (\(PGS.Only nId) -> NodeId nId) ns
  where
    query :: PGS.Query
    query = [sql| SELECT id FROM nodes WHERE typename = ? |]



-- nodeStoryTable :: Table NodeStoryRead NodeStoryWrite
-- nodeStoryTable =
--   Table "node_stories"
--     ( pNodeStory NodeStoryDB { node_id             = tableField "node_id"
--                              , version             = tableField "version"
--                              , ngrams_type_id      = tableField "ngrams_type_id"
--                              , ngrams_id           = tableField "ngrams_id"
--                              , ngrams_repo_element = tableField "ngrams_repo_element"
--                              } )

-- nodeStoryArchiveTable :: Table NodeStoryArchiveRead NodeStoryArchiveWrite
-- nodeStoryArchiveTable =
--   Table "node_story_archive_history"
--     ( pNodeArchiveStory NodeStoryArchiveDB { a_node_id = tableField "node_id"
--                                            , archive   = tableField "archive" } )

-- nodeStorySelect :: Select NodeStoryRead
-- nodeStorySelect = selectTable nodeStoryTable

-- NOTE "first patch in the _a_history list is the most recent"
getNodeArchiveHistory :: PGS.Connection -> NodeId -> IO [NgramsStatePatch']
getNodeArchiveHistory c nodeId = do
  as <- runPGSQuery c query (PGS.Only nodeId) :: IO [(TableNgrams.NgramsType, NgramsTerm, NgramsPatch)]
  pure $ (\(ngramsType, terms, patch) -> fst $ PM.singleton ngramsType (NgramsTablePatch $ fst $ PM.singleton terms patch)) <$> as
  where
    query :: PGS.Query
    query = [sql| SELECT ngrams_type_id, terms, patch
                    FROM node_story_archive_history
                    JOIN ngrams ON ngrams.id = ngrams_id
                    WHERE node_id = ?
                    ORDER BY version DESC |]

ngramsIdQuery :: PGS.Query
ngramsIdQuery = [sql| SELECT id FROM ngrams WHERE terms = ? |]


insertNodeArchiveHistory :: PGS.Connection -> NodeId -> Version -> [NgramsStatePatch'] -> IO ()
insertNodeArchiveHistory _ _ _ [] = pure ()
insertNodeArchiveHistory c nodeId version (h:hs) = do
  let tuples = mconcat $ (\(nType, (NgramsTablePatch patch)) ->
                           (\(term, p) ->
                              (nodeId, nType, term, p)) <$> PM.toList patch) <$> PM.toList h :: [(NodeId, TableNgrams.NgramsType, NgramsTerm, NgramsPatch)]
  tuplesM <- mapM (\(nId, nType, term, patch) -> do
                      ngrams <- runPGSQuery c ngramsIdQuery (PGS.Only term)
                      pure $ (\(PGS.Only termId) -> (nId, nType, termId, term, patch)) <$> (headMay ngrams)
                      ) tuples :: IO [Maybe (NodeId, TableNgrams.NgramsType, Int, NgramsTerm, NgramsPatch)]
  _ <- runPGSExecuteMany c query $ ((\(nId, nType, termId, _term, patch) -> (nId, nType, termId, patch, version)) <$> (catMaybes tuplesM))
  _ <- insertNodeArchiveHistory c nodeId version hs
  pure ()
  where

    query :: PGS.Query
    query = [sql| INSERT INTO node_story_archive_history(node_id, ngrams_type_id, ngrams_id, patch, version) VALUES (?, ?, ?, ?, ?) |]

getNodeStory :: PGS.Connection -> NodeId -> IO NodeListStory
getNodeStory c nId@(NodeId nodeId) = do
  --res <- withResource pool $ \c -> runSelect c query :: IO [NodeStoryPoly NodeId Version Int Int NgramsRepoElement]
  res <- runPGSQuery c nodeStoriesQuery (PGS.Only nodeId) :: IO [(Version, TableNgrams.NgramsType, NgramsTerm, NgramsRepoElement)]
  -- We have multiple rows with same node_id and different (ngrams_type_id, ngrams_id).
  -- Need to create a map: {<node_id>: {<ngrams_type_id>: {<ngrams_id>: <data>}}}
  let dbData = map (\(version, ngramsType, ngrams, ngrams_repo_element) ->
                      Archive { _a_version = version
                              , _a_history = []
                              , _a_state   = Map.singleton ngramsType $ Map.singleton ngrams ngrams_repo_element }) res
  -- NOTE When concatenating, check that the same version is for all states
  pure $ NodeStory $ Map.singleton nId $ foldl combine mempty dbData
  --pure $ NodeStory $ Map.fromListWith (<>) $ (\(NodeStoryDB nId a) -> (nId, a)) <$> res
  where
    -- NOTE (<>) for Archive doesn't concatenate states, so we have to use `combine`
    combine a1 a2 = a1 & a_state %~ combineState (a2 ^. a_state)
                       & a_version .~ (a2 ^. a_version)  -- version should be updated from list, not taken from the empty Archive

nodeStoriesQuery :: PGS.Query
nodeStoriesQuery = [sql| SELECT version, ngrams_type_id, terms, ngrams_repo_element
                           FROM node_stories
                           JOIN ngrams ON ngrams.id = ngrams_id
                           WHERE node_id = ? |]

type ArchiveStateList = [(TableNgrams.NgramsType, NgramsTerm, NgramsRepoElement)]

-- Functions to convert archive state (which is a Map NgramsType (Map
-- NgramsTerm NgramsRepoElement)) to/from a flat list
archiveStateAsList :: NgramsState' -> ArchiveStateList
archiveStateAsList s = mconcat $ (\(nt, ntm) -> (\(n, nre) -> (nt, n, nre)) <$> Map.toList ntm) <$> Map.toList s

archiveStateFromList :: ArchiveStateList -> NgramsState'
archiveStateFromList l = Map.fromListWith (<>) $ (\(nt, t, nre) -> (nt, Map.singleton t nre)) <$> l

-- | This function inserts whole new node story and archive for given node_id.
insertNodeStory :: PGS.Connection -> NodeId -> ArchiveList -> IO ()
insertNodeStory c (NodeId nId) a = do
  _ <- mapM (\(ngramsType, ngrams, ngramsRepoElement) -> do
                termIdM <- runPGSQuery c ngramsIdQuery (PGS.Only ngrams) :: IO [PGS.Only Int64]
                case headMay termIdM of
                  Nothing -> pure 0
                  Just (PGS.Only termId) -> runPGSExecuteMany c query [(nId, a ^. a_version, ngramsType, termId, ngramsRepoElement)]) $ archiveStateAsList $ a ^. a_state
             -- runInsert c $ insert ngramsType ngrams ngramsRepoElement) $ archiveStateAsList _a_state

  pure ()
  where
    query :: PGS.Query
    query = [sql| INSERT INTO node_stories(node_id, ngrams_type_id, ngrams_id, ngrams_repo_element) VALUES (?, ?, ?, ?) |]
    -- insert ngramsType ngrams ngramsRepoElement =
    --   Insert { iTable      = nodeStoryTable
    --          , iRows       = [NodeStoryDB { node_id = sqlInt4 nId
    --                                       , version = sqlInt4 _a_version
    --                                       , ngrams_type_id = sqlInt4 $ TableNgrams.ngramsTypeId ngramsType
    --                                       , ngrams_id = ...
    --                                       , ngrams_repo_element = sqlValueJSONB ngramsRepoElement
    --                                       }]
    --          , iReturning  = rCount
    --          , iOnConflict = Nothing }

insertArchiveList :: PGS.Connection -> NodeId -> ArchiveList -> IO ()
insertArchiveList c nodeId a = do
  _ <- mapM_ (\(nt, n, nre) -> runPGSExecute c query (nodeId, a ^. a_version, nt, nre, n)) (archiveStateAsList $ a ^. a_state)
  --_ <- runPGSExecuteMany c query $ (\(nt, n, nre) -> (nodeId, a ^. a_version, nt, nre, n)) <$> (archiveStateAsList $ a ^. a_state)
  pure ()
  where
    query :: PGS.Query
    query = [sql| INSERT INTO node_stories(node_id, version, ngrams_type_id, ngrams_id, ngrams_repo_element)
                    SELECT ?, ?, ?, ngrams.id, ? FROM ngrams WHERE terms = ? |]

deleteArchiveList :: PGS.Connection -> NodeId -> ArchiveList -> IO ()
deleteArchiveList c nodeId a = do
  _ <- mapM_ (\(nt, n, _) -> runPGSExecute c query (nodeId, nt, n)) (archiveStateAsList $ a ^. a_state)
  --_ <- runPGSExecuteMany c query $ (\(nt, n, _) -> (nodeId, nt, n)) <$> (archiveStateAsList $ a ^. a_state)
  pure ()
  where
    query :: PGS.Query
    query = [sql| WITH (SELECT id FROM ngrams WHERE terms = ?) AS ngrams
                  DELETE FROM node_stories
                    WHERE node_id = ? AND ngrams_type_id = ? AND ngrams_id IN (SELECT id FROM ngrams WHERE terms = ?) |]

updateArchiveList :: PGS.Connection -> NodeId -> ArchiveList -> IO ()
updateArchiveList c nodeId a = do
  let params = (\(nt, n, nre) -> (nre, nodeId, nt, n)) <$> (archiveStateAsList $ a ^. a_state)
  --q <- PGS.format c query params
  --printDebug "[updateArchiveList] query" q
  _ <- mapM (\p -> runPGSExecute c query p) params
  pure ()
  where
    query :: PGS.Query
    query = [sql| UPDATE node_stories
                    SET ngrams_repo_element = ?
                    WHERE node_id = ? AND ngrams_type_id = ? AND ngrams_id IN (SELECT id FROM ngrams WHERE terms = ?) |]

-- | This function updates the node story and archive for given node_id.
updateNodeStory :: PGS.Connection -> NodeId -> ArchiveList -> ArchiveList -> IO ()
updateNodeStory c nodeId@(NodeId _nId) currentArchive newArchive = do
  -- STEPS

  -- 0. We assume we're inside an advisory lock

  -- 1. Find differences (inserts/updates/deletes)
  let currentList = archiveStateAsList $ currentArchive ^. a_state
  let newList = archiveStateAsList $ newArchive ^. a_state
  let currentSet = Set.fromList $ (\(nt, n, _) -> (nt, n)) <$> currentList
  let newSet = Set.fromList $ (\(nt, n, _) -> (nt, n)) <$> newList

  let inserts = filter (\(nt, n, _) -> Set.member (nt, n) $ Set.difference newSet currentSet) newList
  --printDebug "[updateNodeStory] inserts" inserts
  let deletes = filter (\(nt, n, _) -> Set.member (nt, n) $ Set.difference currentSet newSet) currentList
  --printDebug "[updateNodeStory] deletes" deletes

  -- updates are the things that are in new but not in current
  let updates = Set.toList $ Set.difference (Set.fromList newList) (Set.fromList currentList)
  --printDebug "[updateNodeStory] updates" $ Text.unlines $ (Text.pack . show) <$> updates

  -- 2. Perform inserts/deletes/updates
  printDebug "[updateNodeStory] applying insert" ()
  insertArchiveList c nodeId $ Archive { _a_version = newArchive ^. a_version
                                       , _a_history = []
                                       , _a_state = archiveStateFromList inserts }
  printDebug "[updateNodeStory] insert applied" ()
    --TODO Use currentArchive ^. a_version in delete and report error
  -- if entries with (node_id, ngrams_type_id, ngrams_id) but
  -- different version are found.
  deleteArchiveList c nodeId $ Archive { _a_version = newArchive ^. a_version
                                       , _a_history = []
                                       , _a_state = archiveStateFromList deletes }
  printDebug "[updateNodeStory] delete applied" ()
  updateArchiveList c nodeId $ Archive { _a_version = newArchive ^. a_version
                                       , _a_history = []
                                       , _a_state = archiveStateFromList updates }
  printDebug "[updateNodeStory] update applied" ()

  pure ()
  -- where
  --   update = Update { uTable      = nodeStoryTable
  --                   , uUpdateWith = updateEasy (\(NodeStoryDB { node_id }) ->
  --                                                 NodeStoryDB { archive = sqlValueJSONB $ Archive { _a_history = emptyHistory
  --                                                                                                                               , ..}
  --                                                                                           , .. })
  --                   , uWhere      = (\row -> node_id row .== sqlInt4 nId)
  --                   , uReturning  = rCount }

-- nodeStoryRemove :: Pool PGS.Connection -> NodeId -> IO Int64
-- nodeStoryRemove pool (NodeId nId) = withResource pool $ \c -> runDelete c delete
--   where
--     delete = Delete { dTable     = nodeStoryTable
--                     , dWhere     = (\row -> node_id row .== sqlInt4 nId)
--                     , dReturning = rCount }

upsertNodeStories :: PGS.Connection -> NodeId -> ArchiveList -> IO ()
upsertNodeStories c nodeId@(NodeId nId) newArchive = do
  printDebug "[upsertNodeStories] START nId" nId
  PGS.withTransaction c $ do
    printDebug "[upsertNodeStories] locking nId" nId
    runPGSAdvisoryXactLock c nId

    -- whether it's insert or update, we can insert node archive history already
    -- NOTE: It is assumed that the most recent change is the first in the
    -- list, so we save these in reverse order
    insertNodeArchiveHistory c nodeId (newArchive ^. a_version) $ reverse $ newArchive ^. a_history

    (NodeStory m) <- getNodeStory c nodeId
    case Map.lookup nodeId m of
      Nothing -> do
        _ <- insertNodeStory c nodeId newArchive
        pure ()
      Just currentArchive  -> do
        _ <- updateNodeStory c nodeId currentArchive newArchive
        pure ()

    printDebug "[upsertNodeStories] STOP nId" nId

writeNodeStories :: PGS.Connection -> NodeListStory -> IO ()
writeNodeStories c (NodeStory nls) = do
  _ <- mapM (\(nId, a) -> upsertNodeStories c nId a) $ Map.toList nls
  pure ()

-- | Returns a `NodeListStory`, updating the given one for given `NodeId`
nodeStoryInc :: PGS.Connection -> Maybe NodeListStory -> NodeId -> IO NodeListStory
nodeStoryInc c Nothing nId = getNodeStory c nId
nodeStoryInc c (Just ns@(NodeStory nls)) nId = do
  case Map.lookup nId nls of
    Nothing -> do
      (NodeStory nls') <- getNodeStory c nId
      pure $ NodeStory $ Map.union nls nls'
    Just _ -> pure ns

nodeStoryIncs :: PGS.Connection -> Maybe NodeListStory -> [NodeId] -> IO NodeListStory
nodeStoryIncs _ Nothing [] = pure $ NodeStory $ Map.empty
nodeStoryIncs c (Just nls) ns = foldM (\m n -> nodeStoryInc c (Just m) n) nls ns
nodeStoryIncs c Nothing (ni:ns) = do
  m <- getNodeStory c ni
  nodeStoryIncs c (Just m) ns

-- nodeStoryDec :: Pool PGS.Connection -> NodeListStory -> NodeId -> IO NodeListStory
-- nodeStoryDec pool ns@(NodeStory nls) ni = do
--   case Map.lookup ni nls of
--     Nothing -> do
--       _ <- nodeStoryRemove pool ni
--       pure ns
--     Just _ -> do
--       let ns' = Map.filterWithKey (\k _v -> k /= ni) nls
--       _ <- nodeStoryRemove pool ni
--       pure $ NodeStory ns'
------------------------------------

readNodeStoryEnv :: Pool PGS.Connection -> IO NodeStoryEnv
readNodeStoryEnv pool = do
  mvar <- nodeStoryVar pool Nothing []
  saver <- mkNodeStorySaver pool mvar
  -- let saver = modifyMVar_ mvar $ \mv -> do
  --       writeNodeStories pool mv
  --       printDebug "[readNodeStoryEnv] saver" mv
  --       let mv' = clearHistory mv
  --       printDebug "[readNodeStoryEnv] saver, cleared" mv'
  --       return mv'
  pure $ NodeStoryEnv { _nse_var    = mvar
                      , _nse_saver  = saver
                      , _nse_getter = nodeStoryVar pool (Just mvar) }

nodeStoryVar :: Pool PGS.Connection -> Maybe (MVar NodeListStory) -> [NodeId] -> IO (MVar NodeListStory)
nodeStoryVar pool Nothing nIds = do
  state <- withResource pool $ \c -> nodeStoryIncs c Nothing nIds
  newMVar state
nodeStoryVar pool (Just mv) nIds = do
  _ <- withResource pool $ \c -> modifyMVar_ mv $ \nsl -> (nodeStoryIncs c (Just nsl) nIds)
  pure mv

-- Debounce is useful since it could delay the saving to some later
-- time, asynchronously and we keep operating on memory only.
mkNodeStorySaver :: Pool PGS.Connection -> MVar NodeListStory -> IO (IO ())
mkNodeStorySaver pool mvns = mkDebounce settings
  where
    settings = defaultDebounceSettings
                 { debounceAction = do
                     -- NOTE: Lock MVar first, then use resource pool.
                     -- Otherwise we could wait for MVar, while
                     -- blocking the pool connection.
                     modifyMVar_ mvns $ \ns -> do
                       withResource pool $ \c -> do
                         --printDebug "[mkNodeStorySaver] will call writeNodeStories, ns" ns
                         writeNodeStories c ns
                         pure $ clearHistory ns
                     --withMVar mvns (\ns -> printDebug "[mkNodeStorySaver] debounce nodestory" ns)
                 , debounceFreq = 1*minute
                 }
    minute = 60*second
    second = 10^(6 :: Int)

clearHistory :: NodeListStory -> NodeListStory
clearHistory (NodeStory ns) = NodeStory $ ns & (traverse . a_history) .~ emptyHistory
  where
    emptyHistory = [] :: [NgramsStatePatch']

currentVersion :: (HasNodeStory env err m) => ListId -> m Version
currentVersion listId = do
  pool <- view connPool
  nls <- withResource pool $ \c -> liftBase $ getNodeStory c listId
  pure $ nls ^. unNodeStory . at listId . _Just . a_version


-- mkNodeStorySaver :: MVar NodeListStory -> Cmd err (Cmd err ())
-- mkNodeStorySaver mvns = mkDebounce settings
--   where
--     settings = defaultDebounceSettings
--                  { debounceAction = withMVar mvns (\ns -> writeNodeStories ns)
--                  , debounceFreq = 1 * minute
-- --                 , debounceEdge = trailingEdge -- Trigger on the trailing edge
--                  }
--     minute = 60 * second
--     second = 10^(6 :: Int)


-----------------------------------------
