## Version 0.0.6.2
* [BACK][FIX] Ngrams List saved in database on halting
* [BACK][FIX] Confluence on Graph

## Version 0.0.6.1
* [FEAT] Spacy Server connection for French (and others) languages
* [FEAT] At startup, check if gargantext.init script has been activated
* [UPGRADE] Use the devops/postgres/upgrade/0.0.6.1.sql uprade script
* [FIX] PubMed Parser with threadDelay
* [BACK][FIX] Hash to remove duplicates on filtered text

## Version 0.0.6
* [OPTIM] Ngrams Table optmization. To upgrade:
  1. `./bin/psql gargantext.ini < devops/postgresql/upgrade/0.0.6.sql`
  2. in `stack --nix repl` run `runCmdReplEasy $ migrateFromDirToDb`
* [FIX] Ngrams Table next button: loads only one time instead of twice previously
* [FRONT][FIX] Resize handler on Write Node
* [FRONT][FIX] Do not highlight ngrams if maximum abstract length > 4500 characters

## Version 0.0.5.9.6
* [BACK][FIX] Nix build ok
* [BACK][OPTI] Confluence optimization
* [FRONT][GACK][FEAT] Team management
* [FRONT][FEAT] Legend for graph

## Version 0.0.5.9.5
* [FRONT][FIX] View Document List fix CSS
* [FRONT][FIX] Node Modal fix

## Version 0.0.5.9.4
* [FIX] Arxiv API fix
* [DESIGN/ERGO] Tree node position highlight

## Version 0.0.5.9.3
* [FEAT] Graph options with Links Strength

## Version 0.0.5.9.2
* [FEAT] User description field to User page
* [FIX] Ngrams Table cache on
* [FEAT] Ngrams Status change from Phylo Explorer
* [OPTIM] Graph Order 2 generation
* [FIX] Forgot password improvement

## Version 0.0.5.9.1
* [FIX] Graph self referencing nodes
* [FIX] Ngrams Table Tree CSS
* [FIX] Ngrams Table Search with enter only
* [FIX] Graph build: removing mergechildren function for tests

## Version 0.0.5.9
* [FIX] Annuaire Contact Page
* [WIP] Graph Debug (mergeNgrams enabled again)

## Version 0.0.5.8.9.9
* [FIX] Debug Graph Labels
* [FIX] schema upgraded, use 0.0.5.7.8.sql to upgrade your database
* [FEAT] Script to create and sending email to user: invitation

## Version 0.0.5.8.9.8
* [ERGO] NgramsTable, change group and search for ngrams to add
* [FIX] Board, Source Chart fix

## Version 0.0.5.8.9.7
* [FEAT] Infomap Clustering

## Version 0.0.5.8.9.6
* [FIX] IsTex crawler working with basic queries (i.e. without quotes)

## Version 0.0.5.8.9.5
* [FIX] FrontEnd maybe ParentId
* [FIX] IsTex crawler

## Version 0.0.5.8.9.4
* [FE] [FEAT] Phylo Explorer, interactions with documents
* [FE] [ERGO] Fonts in Ngrams Table

## Version 0.0.5.8.9.3
* [BE] [FIX] garg password function
* [FE] [FIX] Trees closing/opening issue
* [FE] [FIX] Viz Explorer Side Panel

## Version 0.0.5.8.9.2
* [FEAT] Lost Password
* [Phylo] More Data in API

## Version 0.0.5.8.9.1
* [FE] [DESIGN] NoteBook, UI/UX Improvements
* [FE] [FEAT] Automatic Sync when adding a new ngrams
* [FE] Frame Page

## Version 0.0.5.8.9
* [COUNTS] Chart update when docs are deleted or added
* [ERGO] Plane navigation improved
* [ERGO] Mouse misalignemnt fixed
* [FIX] Date parser WOS
* [FIX] Node names: List -> Terms

## Version 0.0.5.8.8.2
* [FE] Fix Contact Page

## Version 0.0.5.8.8.1
* [FE] Fix regression on Graph Explorer: edges color + confluence filter

## Version 0.0.5.8.8
* [FE] Fix regression on Graph Explorer for annuaire
* [FE] Graph Doc Focus

## Version 0.0.5.8.7.2
* [BE] Docker solution for codebook

## Version 0.0.5.8.7.1
* [BE] Annuaire pairing, using full first name

## Version 0.0.5.8.7
* [FE] Graph Explorer Document exploration improvements

## Version 0.0.5.8.6
* [FE] Plane navigation improvements

## Version 0.0.5.8.5.1
* [FRONT] FIX CSS Forest

## Version 0.0.5.8.5
* [FRONT] CSS + Design, Graph Toolbar and many things
* [BACK] Security FIX GQL route
* [BACK] Arxiv API connexion

## Version 0.0.5.8.4
* [BACK] GraphQL routes
* [FRONT] CSS, Forest Sidebar
* [HAL] parser back and front

## Version 0.0.5.8.3
* [CRAWLERS] HAL for organizations, example done for IMT

## Version 0.0.5.8.2
* [FIX] Regex Error on HAL Date parsing with Duckling

## Version 0.0.5.8.1
* [FIX] Folder Up button working well now, using GraphQL

## Version 0.0.5.8
* [FIX] reindex ngrams-contexts function
* [PARAM] decreasing the Candidate list
* [FEAT] enabling Notebooks for Teams
* [REFACT] Page user and email refactoring

## Version 0.0.5.7.9.1
* [FIX] Group revert + NLP French API implemented (WIP)
* Default Names of Folder and Frames simplified

## Version 0.0.5.7.9
* [FEAT] New NLP server for postagging
* [FIX] Spinglass unconnected componnent of graph

## Version 0.0.5.7.8
* [FIX] PubMed limit parser

## Version 0.0.5.7.7
* [FEAT FIX] Link Annuaire Corpus (WIP)
* [UPGRADE METHOD] ./bin/psql gargantext.ini < devops/postgres/upgrade/0.0.5.7.7.sql

## Version 0.0.5.7.6
* [FIX] Default behavior of Ngrams Table: Cache off and Desc order by score

## Version 0.0.5.7.5
* [FIX] Progress length

## Version 0.0.5.7.4
* [FIX] User Page info get/update/security

## Version 0.0.5.7.3
* [OPTIM] HAL and PubMed parsers with Conduit
* [BACK] Zip files added

## Version 0.0.5.7.2
* [FIX] Phylo default parameters on frontend side

## Version 0.0.5.7.1
* [FIX] Phylo error findBounds fixed

## Version 0.0.5.7
* [FEAT] Phylo Backend/Frontend connected for tests

## Version 0.0.5.6.7
* [BACK] fix limit with MAX_DOCS_SCRAPERS
* [FEAT] Users Password Sugar function : in repl, runCmdReplEasy $ updateUsersPassword  ["user@mail.com"]

## Version 0.0.5.6.6
* [BACK] CSV List post and reindex after (for both CSV and JSON)

## Version 0.0.5.6.5
* [BACK] HAL parser with Conduit

## Version 0.0.5.6.4
* [FRONT] Forest Tooltip + Async progress bar fix

## Version 0.0.5.6.3
* [BACK][EXPORT][GEXF] node size

## Version 0.0.5.6.2
* [FRONT][FIX] Ngrams Batch change

## Version 0.0.5.6.1
* [BACK][FEAT] Confluence Method connection

## Version 0.0.5.6
* [BACK][FEAT] Phylo backend connection
* [FRONT] Editable Metadata

## Version 0.0.5.5.7
* [FRONT][FIX] NgramsTable Cache search.

## Version 0.0.5.5.6
* [BACK][FIX] ./bin/psql gargantext.ini < devops/posgres/upgrade/0.0.5.5.6.sql
* [FRONT] fix NodeType list show (Nodes options)

## Version 0.0.5.5.5
* [FORNT] fix Graph Explorer search ngrams
* [FRONT] fix NodeType list show (main Nodes)

## Version 0.0.5.5.4
* [BACK][OPTIM] NgramsTable scores
* [BACK] bin/client script to analyze backend performance and reproduce bugs
* [FRONT] Adding Language selection

## Version 0.0.5.5.3
* [BACK] Adding a Max limit for others lists.

## Version 0.0.5.5.2
* [BACK][OPTIM] Index on node_node_ngrams to seed up ngrams table score
  queries. Please execute the upgrade SQL script
  devops/postgres/0.0.5.5.2.sql

## Version 0.0.5.5.1
* [BACK] FIX Graph Explorer search with selected ngrams
* [FRONT] Clean CSS

## Version 0.0.5.5
* [FRONT] Visio frame removed, using a new tab instead (which is working)
* [BACK] Scores on the docs view fixed

## Version 0.0.5.3
* [FRONT] SSL local option

## Version 0.0.5.2
* [QUAL] Scores in Ngrams Table fixed during workflow and user can
  refresh it if needed.

## Version 0.0.5.1
* [OPTIM] Upgrade fix with indexes and scores counts

## Version 0.0.5
* [OPTIM][DATABASE] Upgrade Schema, move conTexts in contexts table which requires a version bump.

## Version 0.0.4.9.9.6
* [BACK] PubMed parser fixed
* [FRONT] Visio Frame resized

## Version 0.0.4.9.9.5
* [FIX] Chart Sort

## Version 0.0.4.9.9.4
* [FEAT] Corpus docs download

## Version 0.0.4.9.9.3
* [BACK] Graph update with force option

## Version 0.0.4.9.9.2
* [BACK] Opaleye Upgrade

## Version 0.0.4.9.9.1
* [FRONT] 350-dev-graph-search-in-forms-not-labels
* [FRONT] 359-dev-input-with-autocomplete

## Version 0.0.4.9.9
* [FIX] Continuous Integration (CI)

## Version 0.0.4.9.8
* [FEAT] All backend routes with clients functions

## Version 0.0.4.9.7
* [FEAT] Searx API done (needs a fix for language selection)

## Version 0.0.4.9.6
* [UX] GT.query forces trees reload for async tasks

## Version 0.0.4.9.5
* [FEAT] Order 2 fixed with filtered edges

## Version 0.0.4.9.4
* [FEAT] Order 1 similarity validated and optimized

## Version 0.0.4.9.3
* [FIX] Node Calc import + more flexible delimiter for CSV parser

## Version 0.0.4.9.2
* [FEAT] Node Calc Parsing added (in tests)

## Version 0.0.4.9.1
* [FIX] Graph Screenshot

## Version 0.0.4.9
* [FEAT] Graph with order 1 and order 2 and node size

## Version 0.0.4.8.9
* BACKEND: fix psql function util without sensitive data
* FRONTEND: fix folder navigation (up link)

## Version 0.0.4.8.8
* FIX for CI

## Version 0.0.4.8.7
* FIX the graph generation (automatic/default, renewal, any distance)

## Version 0.0.4.8.6
* FIX the ngrams grouping

## Version 0.0.4.8.5
* Unary document insertion: Doc table is reloaded after upload

## Version 0.0.4.8.4
* Migration: instance dev is now dev.sub.gargantext.org

## Version 0.0.4.1
* Refact/code design better syntax for DataType fields

## Version 0.0.4
* Fix the search in Title and abstracts.
* [UPGRADE] execute devops/postgres/upgrade/0.0.4.sql to your database to upgrade it

## Version 0.0.3.9.1
* Graph Update fix
* Document view: full text removed

## Version 0.0.0.2
* Fix the community detection.
* TextFlow starts to make sense

## Version 0.0.0.1
* Very first version (main functions ready for tests) of Haskell Version
  of Gargantext. Previous versions (3) were written with another
  language and another framework (Python/Javascript mainly).
