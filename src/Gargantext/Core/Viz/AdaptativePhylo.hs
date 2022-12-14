{-|
Module      : Gargantext.Core.Viz.AdaptativePhylo
Description : Phylomemy definitions and types.
Copyright   : (c) CNRS, 2017-Present
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

Specifications of Phylomemy export format.

Phylomemy can be described as a Temporal Graph with different scale of
granularity of group of ngrams (terms and multi-terms).

The main type is Phylo which is synonym of Phylomemy (only difference is
the number of chars).

References:
Chavalarias, D., Cointet, J.-P., 2013. Phylomemetic patterns
in science evolution — the rise and fall of scientific fields. PloS
one 8, e54847.
-}

{-# LANGUAGE DeriveAnyClass   #-}
{-# LANGUAGE TemplateHaskell   #-}

module Gargantext.Core.Viz.AdaptativePhylo where

import Data.Aeson
import Data.Aeson.TH (deriveJSON)
import Data.Text   (Text, pack)
import Data.Vector (Vector)
import Data.Map (Map)

import Gargantext.Core.Utils.Prefix (unPrefix)
import Gargantext.Prelude
import Gargantext.Core.Text.Context (TermList)

import GHC.Generics
import GHC.IO (FilePath)
import Control.DeepSeq (NFData)
import Control.Lens (makeLenses)

import qualified Data.Text.Lazy as TextLazy


----------------
-- | Config | --
----------------  


data CorpusParser = 
      Wos  {_wos_limit  :: Int}
    | Csv  {_csv_limit  :: Int}
    | Csv' {_csv'_limit :: Int}
    deriving (Show,Generic,Eq) 

data SeaElevation = 
      Constante  
      { _cons_start :: Double
      , _cons_step  :: Double }
    | Adaptative 
      { _adap_granularity :: Double }
    deriving (Show,Generic,Eq)

data Proximity = 
      WeightedLogJaccard 
      { _wlj_sensibility   :: Double
{-
      -- , _wlj_thresholdInit :: Double
      -- , _wlj_thresholdStep :: Double
      -- | max height for sea level in temporal matching
      -- , _wlj_elevation     :: Double
-}
      }
    | WeightedLogSim 
      { _wlj_sensibility   :: Double
{-
      -- , _wlj_thresholdInit :: Double
      -- , _wlj_thresholdStep :: Double
      -- | max height for sea level in temporal matching
      -- , _wlj_elevation     :: Double
-}
      } 
    | Hamming 
    deriving (Show,Generic,Eq) 


data SynchronyScope = SingleBranch | SiblingBranches | AllBranches deriving (Show,Generic,Eq)

data SynchronyStrategy = MergeRegularGroups | MergeAllGroups deriving (Show,Generic,Eq)

data Synchrony = 
      ByProximityThreshold
      { _bpt_threshold :: Double 
      , _bpt_sensibility :: Double
      , _bpt_scope :: SynchronyScope
      , _bpt_strategy :: SynchronyStrategy }
    | ByProximityDistribution
      { _bpd_sensibility :: Double
      , _bpd_strategy :: SynchronyStrategy } 
    deriving (Show,Generic,Eq)     


data TimeUnit = 
      Year 
      { _year_period :: Int
      , _year_step   :: Int
      , _year_matchingFrame :: Int }
    | Month 
      { _month_period :: Int
      , _month_step   :: Int
      , _month_matchingFrame :: Int }      
    | Week 
      { _week_period :: Int
      , _week_step   :: Int
      , _week_matchingFrame :: Int }
    | Day 
      { _day_period :: Int
      , _day_step   :: Int
      , _day_matchingFrame :: Int }      
      deriving (Show,Generic,Eq) 

data CliqueFilter = ByThreshold | ByNeighbours deriving (Show,Generic,Eq)

data Clique = 
      Fis 
      { _fis_support :: Int
      , _fis_size    :: Int }
    | MaxClique
      { _mcl_size      :: Int
      , _mcl_threshold :: Double
      , _mcl_filter    :: CliqueFilter } 
      deriving (Show,Generic,Eq)      


data Quality = 
     Quality { _qua_granularity :: Double
             , _qua_minBranch   :: Int }
      deriving (Show,Generic,Eq)   


data Config = 
     Config { corpusPath     :: FilePath
            , listPath       :: FilePath
            , outputPath     :: FilePath
            , corpusParser   :: CorpusParser
            , phyloName      :: Text
            , phyloLevel     :: Int
            , phyloProximity :: Proximity
            , seaElevation   :: SeaElevation
            , findAncestors  :: Bool
            , phyloSynchrony :: Synchrony
            , phyloQuality   :: Quality
            , timeUnit       :: TimeUnit
            , clique         :: Clique
            , exportLabel    :: [PhyloLabel]
            , exportSort     :: Sort
            , exportFilter   :: [Filter]  
            } deriving (Show,Generic,Eq)


defaultConfig :: Config
defaultConfig = 
     Config { corpusPath     = ""
            , listPath       = ""
            , outputPath     = ""
            , corpusParser   = Csv 1000
            , phyloName      = pack "Default Phylo"
            , phyloLevel     = 2
            , phyloProximity = WeightedLogJaccard 10
            , seaElevation   = Constante 0.1 0.1
            , findAncestors  = True
            , phyloSynchrony = ByProximityThreshold 0.1 10 SiblingBranches MergeAllGroups
            , phyloQuality   = Quality 0 1
            , timeUnit       = Year 3 1 5
            , clique         = MaxClique 0 3 ByNeighbours
            , exportLabel    = [BranchLabel MostEmergentTfIdf 2, GroupLabel MostEmergentInclusive 2]
            , exportSort     = ByHierarchy
            , exportFilter   = [ByBranchSize 2]  
            }

instance FromJSON Config
instance ToJSON Config
instance FromJSON CorpusParser
instance ToJSON CorpusParser
instance FromJSON Proximity
instance ToJSON Proximity
instance FromJSON SeaElevation
instance ToJSON SeaElevation
instance FromJSON TimeUnit
instance ToJSON TimeUnit
instance FromJSON CliqueFilter
instance ToJSON CliqueFilter
instance FromJSON Clique
instance ToJSON Clique
instance FromJSON PhyloLabel
instance ToJSON PhyloLabel
instance FromJSON Tagger
instance ToJSON Tagger
instance FromJSON Sort
instance ToJSON Sort
instance FromJSON Order
instance ToJSON Order
instance FromJSON Filter
instance ToJSON Filter
instance FromJSON SynchronyScope
instance ToJSON SynchronyScope
instance FromJSON SynchronyStrategy
instance ToJSON SynchronyStrategy
instance FromJSON Synchrony
instance ToJSON Synchrony
instance FromJSON Quality
instance ToJSON Quality


-- | Software parameters
data Software =
     Software { _software_name    :: Text
              , _software_version :: Text
     } deriving (Generic, Show, Eq)

defaultSoftware :: Software
defaultSoftware = 
      Software { _software_name    = pack "Gargantext"
               , _software_version = pack "v4" }


-- | Global parameters of a Phylo
data PhyloParam =
     PhyloParam { _phyloParam_version  :: Text
                , _phyloParam_software :: Software
                , _phyloParam_config   :: Config
     } deriving (Generic, Show, Eq)

defaultPhyloParam :: PhyloParam
defaultPhyloParam =
      PhyloParam { _phyloParam_version  = pack "v2.adaptative"
                 , _phyloParam_software = defaultSoftware
                 , _phyloParam_config   = defaultConfig }


------------------
-- | Document | --
------------------

-- | Date : a simple Integer
type Date = Int

-- | Ngrams : a contiguous sequence of n terms
type Ngrams = Text

-- Document : a piece of Text linked to a Date
-- date = computational date; date' = original string date yyyy-mm-dd
data Document = Document
      { date    :: Date
      , date'   :: Text
      , text    :: [Ngrams]
      , weight  :: Maybe Double
      , sources :: [Text]
      } deriving (Eq,Show,Generic,NFData)  


--------------------
-- | Foundation | --
--------------------


-- | The Foundations of a Phylo created from a given TermList 
data PhyloFoundations = PhyloFoundations
      { _foundations_roots   :: !(Vector Ngrams)
      , _foundations_mapList :: TermList
      } deriving (Generic, Show, Eq)


data PhyloSources = PhyloSources
      { _sources :: !(Vector Text) } deriving (Generic, Show, Eq)


---------------------------
-- | Coocurency Matrix | --
---------------------------


-- | Cooc : a coocurency matrix between two ngrams
type Cooc =  Map (Int,Int) Double


-------------------
-- | Phylomemy | --
-------------------


-- | Phylo datatype of a phylomemy
--  foundations : the foundations of the phylo
--  timeCooc : a Map of coocurency by minimal unit of time (ex: by year)
--  timeDocs : a Map with the numbers of docs by minimal unit of time (ex: by year)
--  param : the parameters of the phylomemy (with the user's configuration)
--  periods : the temporal steps of a phylomemy
data Phylo =
     Phylo { _phylo_foundations  :: PhyloFoundations
           , _phylo_sources      :: PhyloSources
           , _phylo_timeCooc     :: !(Map Date Cooc)
           , _phylo_timeDocs     :: !(Map Date Double)
           , _phylo_termFreq     :: !(Map Int Double)
           , _phylo_lastTermFreq :: !(Map Int Double)           
           , _phylo_horizon      :: !(Map (PhyloGroupId,PhyloGroupId) Double)           
           , _phylo_groupsProxi  :: !(Map (PhyloGroupId,PhyloGroupId) Double)
           , _phylo_param        :: PhyloParam
           , _phylo_periods      :: Map PhyloPeriodId PhyloPeriod
           }
           deriving (Generic, Show, Eq)


-- | PhyloPeriodId : the id of a given period
type PhyloPeriodId = (Date,Date)

-- | PhyloPeriod : steps of a phylomemy on a temporal axis
--  id: tuple (start date, end date) of the temporal step of the phylomemy
--  levels: levels of granularity
data PhyloPeriod =
     PhyloPeriod { _phylo_periodPeriod  :: (Date,Date)
                 , _phylo_periodPeriod' :: (Text,Text)
                 , _phylo_periodLevels  :: Map PhyloLevelId PhyloLevel
                 } deriving (Generic, Show, Eq)   


-- | Level : a level of clustering
type Level = Int

-- | PhyloLevelId : the id of a level of clustering in a given period 
type PhyloLevelId  = (PhyloPeriodId,Level)

-- | PhyloLevel : levels of phylomemy on a synchronic axis
-- Levels description:
-- Level 0: The foundations and the base of the phylo
-- Level 1: First level of clustering (the Fis)
-- Level [2..N]: Nth level of synchronic clustering (cluster of Fis)
data PhyloLevel =
     PhyloLevel { _phylo_levelPeriod  :: (Date,Date)
                , _phylo_levelPeriod' :: (Text,Text)
                , _phylo_levelLevel   :: Level 
                , _phylo_levelGroups  :: Map PhyloGroupId PhyloGroup
                } 
                deriving (Generic, Show, Eq)   


type PhyloGroupId  = (PhyloLevelId, Int)

-- | BranchId : (a level, a sequence of branch index)
-- the sequence is a path of heritage from the most to the less specific branch
type PhyloBranchId = (Level, [Int])

-- | PhyloGroup : group of ngrams at each level and period
data PhyloGroup = 
      PhyloGroup { _phylo_groupPeriod   :: (Date,Date)
                 , _phylo_groupPeriod'  :: (Text,Text)
                 , _phylo_groupLevel    :: Level
                 , _phylo_groupIndex    :: Int         
                 , _phylo_groupLabel    :: Text
                 , _phylo_groupSupport  :: Support
                 , _phylo_groupWeight   :: Maybe Double
                 , _phylo_groupSources  :: [Int]                 
                 , _phylo_groupNgrams   :: [Int]
                 , _phylo_groupCooc     :: !(Cooc)
                 , _phylo_groupBranchId :: PhyloBranchId
                 , _phylo_groupMeta     :: Map Text [Double]
                 , _phylo_groupLevelParents  :: [Pointer]
                 , _phylo_groupLevelChilds   :: [Pointer]
                 , _phylo_groupPeriodParents :: [Pointer]
                 , _phylo_groupPeriodChilds  :: [Pointer]
                 , _phylo_groupAncestors     :: [Pointer]
                 }
                 deriving (Generic, Show, Eq, NFData)

-- | Weight : A generic mesure that can be associated with an Id
type Weight = Double

-- | Pointer : A weighted pointer to a given PhyloGroup
type Pointer = (PhyloGroupId, Weight)

data Filiation = ToParents | ToChilds deriving (Generic, Show)    
data PointerType = TemporalPointer | LevelPointer deriving (Generic, Show)                


----------------------
-- | Phylo Clique | --
----------------------

-- | Support : Number of Documents where a Clique occurs
type Support  = Int

data PhyloClique = PhyloClique
  { _phyloClique_nodes   :: [Int]
  , _phyloClique_support :: Support
  , _phyloClique_period  :: (Date,Date)
  , _phyloClique_weight  :: Maybe Double
  , _phyloClique_sources :: [Int]
  } deriving (Generic,NFData,Show,Eq)

----------------
-- | Export | --
----------------

type DotId = TextLazy.Text

data EdgeType = GroupToGroup | BranchToGroup | BranchToBranch | GroupToAncestor | PeriodToPeriod deriving (Show,Generic,Eq)

data Filter = ByBranchSize { _branch_size :: Double } deriving (Show,Generic,Eq)

data Order = Asc | Desc deriving (Show,Generic,Eq)

data Sort = ByBirthDate { _sort_order :: Order } | ByHierarchy deriving (Show,Generic,Eq)

data Tagger = MostInclusive | MostEmergentInclusive | MostEmergentTfIdf deriving (Show,Generic,Eq)

data PhyloLabel = 
      BranchLabel
      { _branch_labelTagger :: Tagger
      , _branch_labelSize   :: Int }
    | GroupLabel
      { _group_labelTagger  :: Tagger
      , _group_labelSize    :: Int }
    deriving (Show,Generic,Eq)

data PhyloBranch =
      PhyloBranch
      { _branch_id :: PhyloBranchId
      , _branch_canonId  :: [Int]
      , _branch_seaLevel :: [Double]
      , _branch_x        :: Double
      , _branch_y        :: Double
      , _branch_w        :: Double
      , _branch_t        :: Double
      , _branch_label    :: Text
      , _branch_meta     :: Map Text [Double]
      } deriving (Generic, Show, Eq)

data PhyloExport =
      PhyloExport
      { _export_groups    :: [PhyloGroup]
      , _export_branches  :: [PhyloBranch]
      } deriving (Generic, Show)

----------------
-- | Lenses | --
----------------

makeLenses ''Config
makeLenses ''Proximity
makeLenses ''SeaElevation
makeLenses ''Quality
makeLenses ''Clique
makeLenses ''PhyloLabel
makeLenses ''TimeUnit
makeLenses ''PhyloFoundations
makeLenses ''PhyloClique
makeLenses ''Phylo
makeLenses ''PhyloPeriod
makeLenses ''PhyloLevel
makeLenses ''PhyloGroup
makeLenses ''PhyloParam
makeLenses ''PhyloExport
makeLenses ''PhyloBranch

------------------------
-- | JSON instances | --
------------------------

instance FromJSON Phylo
instance ToJSON Phylo
instance FromJSON PhyloSources
instance ToJSON PhyloSources
instance FromJSON PhyloParam
instance ToJSON PhyloParam
instance FromJSON PhyloPeriod
instance ToJSON PhyloPeriod
instance FromJSON PhyloLevel
instance ToJSON PhyloLevel
instance FromJSON Software
instance ToJSON Software
instance FromJSON PhyloGroup
instance ToJSON PhyloGroup

$(deriveJSON (unPrefix "_foundations_"  ) ''PhyloFoundations)
