
module Gargantext.Utils.Prefix where

import Prelude

import Data.Aeson (Value, defaultOptions, parseJSON)
import Data.Aeson.TH (Options, fieldLabelModifier, omitNothingFields)
import Data.Aeson.Types (Parser)
import Data.Char (toLower)
import Data.Monoid ((<>))
import Text.Read (Read(..),readMaybe)


-- | Aeson Options that remove the prefix from fields
unPrefix :: String -> Options
unPrefix prefix = defaultOptions
  { fieldLabelModifier = unCapitalize . dropPrefix prefix
  , omitNothingFields = True
  }

-- | Lower case leading character
unCapitalize :: String -> String
unCapitalize [] = []
unCapitalize (c:cs) = toLower c : cs

-- | Remove given prefix
dropPrefix :: String -> String -> String
dropPrefix prefix input = go prefix input
  where
    go pre [] = error $ conStringual $ "prefix leftover: " <> pre
    go [] (c:cs) = c : cs
    go (p:preRest) (c:cRest)
      | p == c = go preRest cRest
      | otherwise = error $ conStringual $ "not equal: " <>  (p:preRest)  <> " " <> (c:cRest)

    conStringual msg = "dropPrefix: " <> msg <> ". " <> prefix <> " " <> input

parseJSONFromString :: (Read a) => Value -> Parser a
parseJSONFromString v = do
  numString <- parseJSON v
  case readMaybe (numString :: String) of
    Nothing -> fail $ "Invalid number for TransactionID: " ++ show v
    Just n -> return n