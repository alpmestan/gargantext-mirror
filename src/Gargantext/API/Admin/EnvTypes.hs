-- |

{-# LANGUAGE TemplateHaskell     #-}

module Gargantext.API.Admin.EnvTypes where

import Control.Lens
import Data.Pool (Pool)
import Database.PostgreSQL.Simple (Connection)
import GHC.Generics (Generic)
import Network.HTTP.Client (Manager)
import Servant.Client (BaseUrl)
import Servant.Job.Async (HasJobEnv(..), Job)
import System.Log.FastLogger
import qualified Servant.Job.Core

import Gargantext.API.Ngrams.Types (HasRepoVar(..), HasRepoSaver(..), HasRepo(..), RepoEnv(..))
import Gargantext.API.Admin.Types
import Gargantext.API.Admin.Orchestrator.Types
import Gargantext.Database.Prelude (HasConnectionPool(..), HasConfig(..))
import Gargantext.Prelude
import Gargantext.Prelude.Config (GargConfig(..))
import Gargantext.Core.NodeStory

data Env = Env
  { _env_settings  :: !Settings
  , _env_logger    :: !LoggerSet
  , _env_pool      :: !(Pool Connection)
  , _env_repo      :: !RepoEnv
  , _env_nodeStory :: !NodeStoryEnv
  , _env_manager   :: !Manager
  , _env_self_url  :: !BaseUrl
  , _env_scrapers  :: !ScrapersEnv
  , _env_config    :: !GargConfig
  }
  deriving (Generic)

makeLenses ''Env

instance HasConfig Env where
  hasConfig = env_config

instance HasConnectionPool Env where
  connPool = env_pool

instance HasNodeStoryEnv Env where
  hasNodeStory = env_nodeStory

instance HasNodeStoryVar Env where
  hasNodeStoryVar = hasNodeStory . nse_getter

instance HasNodeStorySaver Env where
  hasNodeStorySaver = hasNodeStory . nse_saver

instance HasSettings Env where
  settings = env_settings

-- Specific to Repo
instance HasRepoVar Env where
  repoVar = repoEnv . repoVar
instance HasRepoSaver Env where
  repoSaver = repoEnv . repoSaver
instance HasRepo Env where
  repoEnv = env_repo




instance Servant.Job.Core.HasEnv Env (Job JobLog JobLog) where
  _env = env_scrapers . Servant.Job.Core._env

instance HasJobEnv Env JobLog JobLog where
  job_env = env_scrapers

data MockEnv = MockEnv
  { _menv_firewall :: !FireWall
  }
  deriving (Generic)

makeLenses ''MockEnv



data DevEnv = DevEnv
  { _dev_env_settings  :: !Settings
  , _dev_env_repo      :: !RepoEnv
  , _dev_env_config    :: !GargConfig
  , _dev_env_pool      :: !(Pool Connection)
  , _dev_env_nodeStory :: !NodeStoryEnv
  }

makeLenses ''DevEnv

instance HasConfig DevEnv where
  hasConfig = dev_env_config

instance HasConnectionPool DevEnv where
  connPool = dev_env_pool

instance HasSettings DevEnv where
  settings = dev_env_settings


instance HasNodeStoryEnv DevEnv where
  hasNodeStory = dev_env_nodeStory

instance HasNodeStoryVar DevEnv where
  hasNodeStoryVar = hasNodeStory . nse_getter

instance HasNodeStorySaver DevEnv where
  hasNodeStorySaver = hasNodeStory . nse_saver


instance HasRepoVar DevEnv where
  repoVar = repoEnv . repoVar
instance HasRepoSaver DevEnv where
  repoSaver = repoEnv . repoSaver
instance HasRepo DevEnv where
  repoEnv = dev_env_repo


