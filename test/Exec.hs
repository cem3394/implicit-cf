module Exec (execute, kNearestNeighbors, matrixFactorization, score) where

import Control.Monad (liftM2)
import Data.Foldable (maximumBy)
import Data.List (intercalate)
import Data.List.Split (splitOn)
import Text.Read (readMaybe)
import Text.CSV 

import qualified Data.Map.Strict as M
import qualified Data.MultiMap as MM
import qualified Data.Vector as V

import qualified MatrixFactorization as MF
import qualified KNearestNeighbors as KN
import Types


execute :: ([Record] -> [Record] -> IO ()) -> FilePath -> FilePath -> IO ()
execute function trainFile testFile = do
  trainData <- readFile trainFile
  testData <- readFile testFile
  let trainCsv = parseCSV trainFile trainData
      testCsv = parseCSV testFile testData
      allCsv = liftM2 (,) trainCsv testCsv
  either print (uncurry function) allCsv

-- | Entry point for user-based Jaccard KNN model
kNearestNeighbors ::  FilePath -> [Record] -> [Record] -> IO ()
kNearestNeighbors outFile train test = let
  train' = tail $ init train --strip header and trailing newline
  test' = tail $ init test
  trainData = countVectorizer train' 
  testData = map (read . head) $ test' :: [User] --works on holdout trx data and test data
  header = ["customerId", "recommendedProducts"]
  recs = KN.recommend trainData testData
  out = map (intercalate "|") $ (map . map) show recs
  format a b = (show a) : b : []
  body = zipWith format testData out
  in writeFile outFile $ printCSV $ header:body

-- | Entry point for SGD latent factor model
matrixFactorization :: FilePath -> [Record] -> [Record] -> IO ()
matrixFactorization outFile train test = do
  let train' = tail $ init train --strip header and trailing newline
      test' = tail $ init test
      trainData = countVectorizer train'
  model <- MF.model trainData
  let testData = map (read . head) $ test' :: [User]
      header = ["customerId", "recommendedProducts"]
      recs = MF.recommend model testData
      out = map (intercalate "|") $ (map . map) show recs
      format a b = (show a) : b : []
      body = zipWith format testData out
  writeFile outFile $ printCSV $ header:body
   
-- | A primitive CTR-style recommendation scorer to run on out-of-sample transaction data
score :: [Record] -> [Record] -> IO ()
score recommended purchased = let
  recommended' = tail $ init recommended --strip header and trailing newline
  purchased' = tail $ init purchased
  purchases = map parseToTuple purchased'
  recs = (map . map) fst $ map M.toList
                         $ map snd 
                         $ map parseToTuple
                         $ recommended'
  userTx = map snd purchases
  submissionScore = sum $ map (uncurry scoreOne) $ zip userTx recs
  in do 
    putStrLn $ "score: " ++ (show $ submissionScore / (fromIntegral $ length recs))

-- | Assigns a 1 if any of the items purchased was in the recommendation list
scoreOne :: ItemRatingMap -> [Item] -> Double
scoreOne purchases items = let
  out = or [ M.member i purchases | i <- items]
  in case out of
   True -> 1.0
   False -> 0.0

-- | Aggregates multiple user transactions into a single UserRatings object
countVectorizer :: [Record] -> [UserRatings]
countVectorizer csv = let
  purchases = map parseToTuple csv
  in M.toList $ M.fromListWith (M.unionWith (+)) purchases
  
-- | Converts a CSV line into a UserRatings tuple
parseToTuple :: Record -> UserRatings
parseToTuple record = let
  read' r = maybe (-1) id (readMaybe r :: Maybe Int)
  name = read' $ head record 
  transaction = map read' $ splitOn "|" $ head $ tail record
  items = M.fromListWith (+) $ map (\k -> (k,1.0)) transaction
  in (name, items)

-- | Conversion utility generating unique user-item-quantity tuples
convert :: FilePath -> FilePath -> IO ()
convert inFilePath outFilePath = let
  header = ["customerId", "itemId", "quantity"]
  transform csv = writeFile outFilePath $ printCSV
                                        $ (header:)
                                        $ toRecords
                                        $ MF.dataSet
                                        $ countVectorizer csv
  in do
    input <- readFile inFilePath
    let csv = parseCSV inFilePath input
    either print transform csv

toRecords :: DataSet -> [Record]
toRecords dataSet = let
  toList (a,b,c) = [a,b,round c] 
  in V.toList $ (fmap . fmap) show $ fmap toList dataSet    
