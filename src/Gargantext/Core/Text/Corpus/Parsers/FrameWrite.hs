module Gargantext.Core.Text.Corpus.Parsers.FrameWrite where

import Control.Applicative ((*>))
import Control.Monad (void)
import Data.Either
import Data.Maybe
import Data.Text hiding (foldl)
import Gargantext.Prelude
import Prelude ((++))
import Text.Parsec hiding (Line)
import Text.Parsec.Number (number)
import Text.Parsec.String


-- https://gitlab.iscpif.fr/gargantext/purescript-gargantext/issues/331

-- title : everything above the first ==
-- Authors : default : anonymous ; except if the following line is encountered ^@@authors: FirstName1, LastName1 ; FirstName2, LastName2 ; etc.
-- date : default : date of last change except if the following line is encountered  ^@@date: 2021-09-10
-- source: Name of the root node except if the following line is encountered ^@@source:
-- By default, 1 framawrite node = 1 document.  Option for further developments: allow to give a level at generation for the split within framawrite node : :
-- 
-- par défaut: un doc == 1 NodeWrite
-- ## mean each ## section will be a new document with title the subsubsection title. Either it features options for author, date etc. or it will inherit the document's option.

sample :: Text
sample =
  unlines
    [ "title1"
    , "title2"
    , "=="
    , "^@@authors: FirstName1, LastName1; FirstName2, LastName2"
    , "^@@date: 2021-09-10"
    , "^@@source: someSource"
    , "document contents 1"
    , "document contents 2"
    ]

sampleUnordered :: Text
sampleUnordered =
  unlines
    [ "title1"
    , "title2"
    , "=="
    , "document contents 1"
    , "^@@date: 2021-09-10"
    , "^@@authors: FirstName1, LastName1; FirstName2, LastName2"
    , "^@@source: someSource"
    , "document contents 2"
    ]

-- parseSample = parse documentP "sample" (unpack sample)
-- parseSampleUnordered = parse documentP "sampleUnordered" (unpack sampleUnordered)
parseLinesSample :: Either ParseError Parsed
parseLinesSample = parseLines sample
parseLinesSampleUnordered :: Either ParseError Parsed
parseLinesSampleUnordered = parseLines sampleUnordered

data Author =
    Author { firstName :: Text
           , lastName :: Text }
    deriving (Show)

data Parsed =
  Parsed { title :: Text
         , authors :: [Author]
         , date :: Maybe Text
         , source :: Maybe Text
         , contents :: Text }
  deriving (Show)

emptyParsed :: Parsed
emptyParsed =
  Parsed { title = ""
         , authors = []
         , date = Nothing
         , source = Nothing
         , contents = "" }

data Date =
  Date { year :: Int
       , month :: Int
       , day :: Int }
  deriving (Show)

data Line =
    LAuthors [Author]
  | LContents Text
  | LDate Date
  | LSource Text
  | LTitle Text
  deriving (Show)

parseLines :: Text -> Either ParseError Parsed
parseLines text = foldl f emptyParsed <$> lst
  where
    lst = parse documentLinesP "" (unpack text)
    f (Parsed { .. }) (LAuthors as) = Parsed { authors = as, .. }
    f (Parsed { .. }) (LContents c) = Parsed { contents = concat [contents, c], .. }
    f (Parsed { .. }) (LDate    d ) = Parsed { date = Just d, .. }
    f (Parsed { .. }) (LSource  s ) = Parsed { source = Just s, .. }
    f (Parsed { .. }) (LTitle   t ) = Parsed { title = t, .. }

documentLinesP :: Parser [Line]
documentLinesP = do
  t <- titleP
  ls <- lineP `sepBy` newline
  pure $ [LTitle $ pack t] ++ ls

lineP :: Parser Line
lineP = do
  choice [ try authorsLineP
         , try dateLineP
         , try sourceLineP
         , contentsLineP ]

authorsLineP :: Parser Line
authorsLineP = do
  authors <- authorsP
  pure $ LAuthors authors

dateLineP :: Parser Line
dateLineP = do
  date <- dateP
  pure $ LDate date

sourceLineP :: Parser Line
sourceLineP = do
  source <- sourceP
  pure $ LSource $ pack source

contentsLineP :: Parser Line
contentsLineP = do
  contents <- many (noneOf "\n")
  pure $ LContents $ pack contents

--------------------

-- documentP = do
--   t <- titleP
--   a <- optionMaybe authorsP
--   d <- optionMaybe dateP
--   s <- optionMaybe sourceP
--   c <- contentsP
--   pure $ Parsed { title = pack t
--                 , authors = fromMaybe [] a
--                 , date = pack <$> d
--                 , source = pack <$> s
--                 , contents = pack c }

titleDelimiterP :: Parser ()
titleDelimiterP = do
  _ <- newline
  _ <- string "=="
  tokenEnd
titleP :: Parser [Char]
titleP = manyTill anyChar (try titleDelimiterP)

authorsPrefixP :: Parser [Char]
authorsPrefixP = do
  _ <- string "^@@authors:"
  many (char ' ')
authorsP :: Parser [Author]
authorsP = try authorsPrefixP *> sepBy authorP (char ';')
authorP :: Parser Author
authorP = do
  fn <- manyTill anyChar (char ',')
  _ <- many (char ' ')
  --ln <- manyTill anyChar (void (char ';') <|> tokenEnd)
  --ln <- manyTill anyChar (tokenEnd)
  ln <- many (noneOf "\n")
  pure $ Author { firstName = pack fn, lastName = pack ln }
  -- manyTill anyChar (void (char '\n') <|> eof)

datePrefixP :: Parser [Char]
datePrefixP = do
  _ <- string "^@@date:"
  many (char ' ')
dateP :: Parser [Char]
dateP = try datePrefixP
        *> many (noneOf "\n")

dateISOP :: Parser Date
dateISOP = do
  year <- number
  _ <- char '-'
  month <- number
  _ <- char '-'
  day <- number
  pure $ Date { year, month, day }

sourcePrefixP :: Parser [Char]
sourcePrefixP = do
  _ <- string "^@@source:"
  many (char ' ')
sourceP :: Parser [Char]
sourceP = try sourcePrefixP
          *> many (noneOf "\n")

-- contentsP :: Parser String
-- contentsP = many anyChar

tokenEnd :: Parser ()
tokenEnd = void (char '\n') <|> eof
