{-# LANGUAGE TypeOperators #-}

module Gargantext.API.Job where

import Data.Swagger
import Servant
import Servant.Job.Async

import Gargantext.API.Admin.Orchestrator.Types (JobLog(..), AsyncJobs)
import Gargantext.API.Prelude (GargServer)
import Gargantext.API.Utils.Job
import Gargantext.Prelude

type API = Summary "Job API (for testing)"
            :> "jobs"
            :> AsyncJobs JobLog '[JSON] () JobLog

-- api :: GargServer API
api =
  serveJobsAPI $ fromJobFunctionS (jobLogInit 0) $ JobFunctionS $ \input -> do
    pushEvent (addRem 2)
    pure $ jobLogInit 0
    
