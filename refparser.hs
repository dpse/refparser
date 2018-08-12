module Main where
import System.IO()
import System.Environment
import qualified Data.Map.Strict as Map
import Text.Regex
import Text.Regex.Posix
import Data.String.Utils

-----------------------------------------------------------------------------------------------------------------------------

matchNext :: String -> String -> Maybe (String, String, String, [String])
matchNext = matchRegexAll . makeRegex

-----------------------------------------------------------------------------------------------------------------------------

-- Maps objects to numbers
type ObjectMap = Map.Map String Int
-- Maps counter names to counter values
type CounterMap = Map.Map String Int

objectLabelRegex :: String
objectLabelRegex = "\\\\label(\\[([^]]*)\\])?{([^}]*)}"
objectRefRegex :: String
objectRefRegex = "\\\\ref{([^}]*)}"
defaultCounterName :: String
defaultCounterName = ""

matchObjectsHelper :: CounterMap -> String -> ObjectMap -> (String, ObjectMap)
matchObjectsHelper counters left objmap = case matchNext objectLabelRegex left of
    Just (textbefore, _, textafter, [_, counter, label]) -> (textbefore ++ fst next, snd next)
        where
            newcounters = Map.insertWith (+) counter 1 counters
            next = matchObjectsHelper newcounters textafter $ Map.insert label (newcounters Map.! counter) objmap
    Nothing -> (left, objmap)
    _ -> (left, objmap)

matchObjects :: String -> (String, ObjectMap)
matchObjects input = matchObjectsHelper Map.empty input Map.empty

formatObjectRefLookup :: [String] -> ObjectMap -> String
formatObjectRefLookup [label] objmap = case Map.lookup label objmap of
	Just counter -> show counter
	Nothing -> "\\ref{" ++ label ++ "}"
formatObjectRefLookup _ _ = []

addObjectRefs :: String -> ObjectMap -> String
addObjectRefs left objmap = case matchNext objectRefRegex left of
	Just (textbefore, _, textafter, submatches) -> textbefore ++ formatObjectRefLookup submatches objmap ++ addObjectRefs textafter objmap
	Nothing -> left

parseObjects :: String -> String
parseObjects = uncurry addObjectRefs . matchObjects

-----------------------------------------------------------------------------------------------------------------------------

-- Maps labels to numbers
type FigureMap = Map.Map String Int

figureLabelRegex :: String
figureLabelRegex = "!\\[([^]\\]*)(\\\\label{([^}]*)}([^]\\]*))?\\]\\((.*)\\)"
figureRefRegex :: String
figureRefRegex = "\\\\ref{([^}]*)}"

formatCaption :: Int -> String -> String -> String
formatCaption counter [] [] = "Figure " ++ show counter
formatCaption counter c1 [] = "Figure " ++ show counter ++ ": " ++ strip c1
formatCaption counter [] c2 = "Figure " ++ show counter ++ ": " ++ strip c2
formatCaption counter c1 c2 = "Figure " ++ show counter ++ ": " ++ strip c1 ++ " " ++ strip c2

figureCaptionFromSubMatches :: Int -> [String] -> (String, String)
figureCaptionFromSubMatches counter [caption1, _, label, caption2, url] = (label, "![" ++ formatCaption counter caption1 caption2 ++ "](" ++ url ++ ")")
figureCaptionFromSubMatches _ _ = ([],[])

matchFiguresHelper :: Int -> String -> FigureMap -> (String, FigureMap)
matchFiguresHelper counter left figmap = case matchNext figureLabelRegex left of
	Just (textbefore, _, textafter, submatches) -> (textbefore ++ snd caption ++ fst next, snd next)
		where
			caption = figureCaptionFromSubMatches counter submatches
			next = matchFiguresHelper (counter + 1) textafter $ Map.insert (fst caption) counter figmap
	Nothing -> (left, figmap)

matchFigures :: String -> (String, FigureMap)
matchFigures input = matchFiguresHelper 1 input Map.empty

formatFigureRefLookup :: [String] -> FigureMap -> String
formatFigureRefLookup [label] figmap = case Map.lookup label figmap of
	Just counter -> show counter
	Nothing -> "\\ref{" ++ label ++ "}"
formatFigureRefLookup _ _ = []

addFigureRefs :: String -> FigureMap -> String
addFigureRefs left figmap = case matchNext figureRefRegex left of
	Just (textbefore, _, textafter, submatches) -> textbefore ++ formatFigureRefLookup submatches figmap ++ addFigureRefs textafter figmap
	Nothing -> left

parseFigures :: String -> String
parseFigures = uncurry addFigureRefs . matchFigures

-----------------------------------------------------------------------------------------------------------------------------

type SectionMap = Map.Map String [Int]

-- Maximum section depth
maxLevels :: Int
maxLevels = 4

sectionHeaderRegex :: String
sectionHeaderRegex = "^([ ]*)(#+)[ ]*(.+)$*"
sectionLabelRegex :: String
sectionLabelRegex = "\r?\n?^[^\\]*\\\\label{([^}]*)}.*$\r?\n?"
sectionRefRegex :: String
sectionRefRegex = "\\\\ref{([^}]*)}"

-- Update counters from ### textmatch
updateCounters :: [Int] -> String -> [Int]
updateCounters counters hashlevels
	| length counters < length hashlevels = counters
	| otherwise = take (length hashlevels - 1) counters ++ [counters !! (length hashlevels - 1) + 1] ++ replicate (length counters - length hashlevels) 0

-- Finds labels in a section text and saves them in a map and removes them from the string
matchSectionLabels :: [Int] -> String -> SectionMap -> (String, SectionMap)
matchSectionLabels counters left secmap = case matchNext sectionLabelRegex left of
	Just (textbefore, _, textafter, [label]) -> (textbefore ++ fst next, snd next)
		where next = matchSectionLabels counters textafter $ Map.insert label counters secmap
	Nothing -> (left, secmap)
	_ -> (left, secmap)

addDots :: [Int] -> String
addDots [] = []
addDots (0:_) = []
addDots [x] = show x
addDots (x:0:_) = show x
addDots (x:xs) = show x ++ "." ++ addDots xs

formatSectionHeader :: String -> [Int] -> String -> String
formatSectionHeader hashlevels counters caption
    | length hashlevels <= maxLevels = hashlevels ++ " " ++ sectionNumber ++ " " ++ caption ++ " {#section-" ++ sectionNumber ++ "}"
    | otherwise = hashlevels ++ " " ++ caption ++ " {#section-" ++ sectionNumber ++ "}"
        where sectionNumber = addDots counters

matchSectionHeadersHelper :: [Int] -> String -> SectionMap -> (String, SectionMap)
matchSectionHeadersHelper counters left secmap = case matchNext sectionHeaderRegex left of
	Just (textbefore, _, textafter, [prespace, hashlevels, caption]) -> (fst prevmatch ++ prespace ++ formatSectionHeader hashlevels newcounters caption ++ fst next, snd next)
		where
			newcounters = updateCounters counters hashlevels
			prevmatch = matchSectionLabels counters textbefore secmap
			next = matchSectionHeadersHelper newcounters textafter $ snd prevmatch
	Nothing ->  matchSectionLabels counters left secmap
	_ -> matchSectionLabels counters left secmap

matchSections :: String -> (String, SectionMap)
matchSections input = matchSectionHeadersHelper (replicate 10 0) input Map.empty

formatSectionRefLookup :: [String] -> SectionMap -> String
formatSectionRefLookup [label] secmap = case Map.lookup label secmap of
	Just counters -> "[" ++ sectionNumber ++ "](#section-" ++ sectionNumber ++ ")" where sectionNumber = addDots counters
	Nothing -> "\\ref{" ++ label ++ "}"
formatSectionRefLookup _ _ = []

addSectionRefs :: String -> SectionMap -> String
addSectionRefs left secmap = case matchNext sectionRefRegex left of
	Just (textbefore, _, textafter, submatches) -> textbefore ++ formatSectionRefLookup submatches secmap ++ addSectionRefs textafter secmap
	Nothing -> left

parseSections :: String -> String
parseSections = uncurry addSectionRefs . matchSections

-----------------------------------------------------------------------------------------------------------------------------

-- Main function
main :: IO ()
main = do
	args <- getArgs
	case args of
		[infile, outfile] -> do
			text <- readFile infile
			writeFile outfile $ parseObjects $ parseSections $ parseFigures text
		_ -> putStrLn "Wrong number of arguments!\n\nUsage: refparser infile outfile"
