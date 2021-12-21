{-|
Module      : Gargantext.Core.Text.Corpus.API.Hal
Description : Pubmed API connection
Copyright   : (c) CNRS, 2017
License     : AGPL + CECILL v3
Maintainer  : team@gargantext.org
Stability   : experimental
Portability : POSIX

-}

module Gargantext.Core.Text.Corpus.API.Hal
    where

import Data.Maybe
import Data.Text (Text, pack, intercalate)

import Gargantext.Core (Lang(..))
import Gargantext.Database.Admin.Types.Hyperdata (HyperdataDocument(..))
import qualified Gargantext.Defaults as Defaults
import Gargantext.Prelude
import qualified Gargantext.Core.Text.Corpus.Parsers.Date as Date
import qualified HAL            as HAL
import qualified HAL.Client     as HAL
import qualified HAL.Doc.Corpus as HAL

get :: Lang -> Text -> Maybe Integer -> IO [HyperdataDocument]
get la q ml = do
  docs <- HAL.getMetadataWith q (Just 0) (fromIntegral <$> ml)
  pure $ either (panic . pack . show) (\d -> map (toDoc' la) $ HAL._docs d) docs

toDoc' :: Lang -> HAL.Corpus -> HyperdataDocument
toDoc' la (HAL.Corpus i t ab d s aus affs struct_id) = do
  let (utctime, (pub_year, pub_month, pub_day)) =
        Date.dateSplit la (maybe (Just $ pack $ show Defaults.year) Just d)
  HyperdataDocument { _hd_bdd = Just "Hal"
                    , _hd_doi = Just $ pack $ show i
                    , _hd_url = Nothing
                    , _hd_uniqId = Nothing
                    , _hd_uniqIdBdd = Nothing
                    , _hd_page = Nothing
                    , _hd_title = Just $ intercalate " " t
                    , _hd_authors = Just $ foldl (\x y -> x <> ", " <> y) "" aus
                    , _hd_institutes = Just $ foldl (\x y -> x <> ", " <> y) "" $ affs <> map (cs . show) struct_id
                    , _hd_source = Just $ maybe "Nothing" identity s
                    , _hd_abstract = Just $ intercalate " " ab
                    , _hd_publication_date = fmap (pack . show) utctime
                    , _hd_publication_year = pub_year
                    , _hd_publication_month = pub_month
                    , _hd_publication_day = pub_day
                    , _hd_publication_hour = Nothing
                    , _hd_publication_minute = Nothing
                    , _hd_publication_second = Nothing
                    , _hd_language_iso2 = Just $ (pack . show) la }

