module Data.Gargantext.Utils.Prefix where


import Control.Monad as X (mzero)
import Data.Aeson as X
import Data.Aeson.TH as X
import Data.Aeson.Types as X
import Data.Char as X (toLower)
-- import Data.Decimal as X
import Data.Maybe as X (catMaybes)
import Data.Monoid as X ((<>))
-- import Data.Scientific as X
import Data.String as X (IsString (..), fromString)
import Data.Text as X (Text, unpack, pack)
import Data.Text.Encoding as X
import Text.Read (readMaybe)


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
    go pre [] = error $ contextual $ "prefix leftover: " <> pre
    go [] (c:cs) = c : cs
    go (p:preRest) (c:cRest)
      | p == c = go preRest cRest
      | otherwise = error $ contextual $ "not equal: " <>  (p:preRest)  <> " " <> (c:cRest)

    contextual msg = "dropPrefix: " <> msg <> ". " <> prefix <> " " <> input

parseJSONFromString :: (Read a) => Value -> Parser a
parseJSONFromString v = do
  numString <- parseJSON v
  case readMaybe (numString :: String) of
    Nothing -> fail $ "Invalid number for TransactionID: " ++ show v
    Just n -> return n
