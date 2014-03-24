--import Data.Array
import Data.Array.IArray
import System.Random
import Data.Ord
import Data.List

argmax                :: (Ord b) => (a -> b) -> [a] -> a
argmax f (x:xs) = _argmaxBy (>) f xs (x, f x)

_argmaxBy :: (b -> b -> Bool) -> (a -> b) -> [a] -> (a,b) -> a
_argmaxBy isBetterThan f = go
    where
    go []     (b,_)  = b
    go (x:xs) (b,fb) = go xs $! cmp x (b,fb)
    
    cmp a (b,fb) = let  fa = f a in
                   if   fa `isBetterThan` fb
                   then (a,fa)
                   else (b,fb)

safeLog :: Float -> Float
safeLog x = if x==0.0 then 0 else log x



data Tile = Tile {val :: Int, merged :: Bool}
	deriving (Read,Eq)
blank :: Tile
blank = Tile {val=0, merged=False}
two :: Tile
two = Tile {val=2, merged=False}
four :: Tile
four = Tile {val=4, merged=False}

pad :: String -> String
pad str | length str < 4 = str ++ (replicate (4 - length str) ' ')
pad str | otherwise = str

instance Show Tile where
	show t | val t == 0 = "----"
	show t = show $ val t

data Move = Up | Down | Lft | Rght
	deriving (Show,Enum,Eq,Read)
getDx :: Move -> Position
getDx Lft = (0,-1)
getDx Rght = (0,1)
getDx Up = (-1,0)
getDx Down = (1,0)

type Position = (Int,Int)

apply :: Position -> Move -> Maybe Position
apply (x,y) move = let (x2,y2) = getDx move in
	case x+x2<4 && x+x2>=0 && y+y2<4 && y+y2>=0 of
		True -> Just (x+x2,y+y2)
		False -> Nothing

data Board = Board {
	arr :: (Array Position Tile),
	score :: Int
	}
	deriving (Eq)

gameOver :: Board -> Bool
gameOver board = (moveList board) == [] || any (\x-> (val x) == 2048) (map (getTile board) enumBoard)


showArr :: Array Position Tile -> String
showArr arr = helper $ map (pad . show . (arr !)) enumBoard --foldl (flip $ (++) . show . (arr !)) "" enumBoard 
	where
	helper :: [String] -> String
	helper (a:b:c:d:xs) = a ++ b ++ c ++ d ++ "\n" ++ helper xs
	helper _ = ""

instance Show Board where
	show board = "score: " ++ show (score board) ++ "\n" ++ showArr (arr board)

incScore :: Int -> Board -> Board
incScore n board = Board {arr = arr board, score = (+n) (score board)}

getTile :: Board -> Position -> Tile
getTile board ps = (arr board) ! ps

setTile :: Board -> Position -> Tile -> Board
setTile board ps tile = Board { arr = (arr board) // [(ps,tile)], score = score board}

setTiles :: Board -> [(Position,Tile)] -> Board
setTiles board xs = Board {arr = (arr board) // xs, score = score board}

incScoreAndSetTiles :: Board -> Int -> [(Position,Tile)] -> Board
incScoreAndSetTiles board n xs = Board {arr = (arr board) // xs, score = (score board) + n}

moveTile :: Board -> Position -> Position -> Board
moveTile board p1 p2 | p1 == p2 =  board
	|otherwise = setTiles board [(p2, getTile board p1), (p1,blank)] --setTile (setTile board p2 (getTile board p1)) p1 blank

resetTile :: Tile -> Tile
resetTile (Tile v _) = Tile v False

enumBoard :: [Position]
enumBoard = [(i,j) | i<-[0..3], j<-[0..3]]

rowsAndCols :: [[Position]]
rowsAndCols = [[(i,j) | i<-[0..3]] | j<-[0..3]] ++ [[(i,j) | j<-[0..3]] | i<-[0..3]]

moveEnum :: Move -> [Position]
moveEnum Up = [(i,j) | i<-[0..3], j<-[0..3]]
moveEnum Down = [(i,j) | i<-[3,2,1,0], j<-[0..3]]
moveEnum Lft = [(i,j) | i<-[0..3], j<-[0..3]]
moveEnum Rght = [(i,j) | i<-[0..3], j<-[3,2,1,0]]


resetBoard :: Board -> Board
resetBoard board = Board { arr = amap resetTile (arr board), score = score board}

blanks :: Board -> [Position]
blanks board = filter (helper board) enumBoard
	where
	helper :: Board -> Position -> Bool
	helper board ps = case getTile board ps of
		(Tile 0 _) -> True
		_ -> False

newBoard :: Board
newBoard = Board { arr = array ((0,0),(3,3)) (map (\x -> (x,blank)) enumBoard), score = 0}

data RandomMove = RandomMove Float Position Tile
	deriving (Show,Read,Eq)

seedOpts :: Board -> [RandomMove]
seedOpts board = two' ++ four'
	where
	two' :: [RandomMove]
	two' = map (\x-> RandomMove (0.9*b1) x two) (blanks board)
	four' :: [RandomMove]
	four' = map (\x -> RandomMove (0.1*b1) x four) (blanks board)
	b1 :: Float
	b1 = 1.0 / (fromIntegral $ length (blanks board))

applyRandomMove :: Board -> RandomMove -> Board
applyRandomMove board (RandomMove _ p t) = setTile board p t
		--foldl helper board xs
	--where
	--helper :: Board -> ((Int,Int,Int),Tile) -> Board
	--helper board (ps,t) = setTile board ps t

seed :: Board -> IO Board
seed board | blanks board /= [] = do
		ps <- choice $ blanks board
		r <- randomRIO (0.0,1.0) :: IO Float
		return $ setTile board ps (if (r < 0.8) then two else four)
	| otherwise = return board

choice :: [a] -> IO a
choice xs = fmap (xs !!) $ randomRIO (0, (length xs) - 1)

isValidMove :: Board -> Move -> Bool
isValidMove board move = (makeMoveNoSeed board move) /= board

moveList :: Board -> [Move]
moveList board | any (\x-> (val x) == 2048) (map (getTile board) enumBoard) = []
	| otherwise = filter (isValidMove board) [Up,Down,Lft,Rght]

moveList' :: Board -> [(Board,Move)]
moveList' board | any ((==2048) . val) $ map (getTile board) enumBoard = []
	| otherwise = filter (\(x,_) -> x /= board) $ map (\x -> (makeMoveNoSeed board x,x)) [Up,Down,Lft,Rght]

makeMoveNoSeed :: Board -> Move -> Board
makeMoveNoSeed board move = resetBoard $ foldl helper board (moveEnum move)
	where
	helper :: Board -> Position -> Board
	helper board ps
		| getTile board ps == blank = board
		| (position board ps) /= ps && val (next board ps) == val (getTile board ps) && 
			not (merged (next board ps)) && (getTile board ps) /= blank = 
			let t=Tile {val = (*2) $ val $ next board ps, merged=True } in 
				incScoreAndSetTiles board ((*2) . val $ getTile board ps) [(position board ps,t),(ps,blank)]  
				--setTile (setTile board (position board ps) t) ps blank
		| otherwise = moveTile board ps $ position board ps
	farthestPosition :: Int -> Position -> Board -> Move -> Position
	farthestPosition v ps board move = case fmap (getTile board) $ apply ps move of
		Nothing -> ps
		Just (Tile 0 _) -> farthestPosition v (fromJust $ apply ps move) board move
		Just (Tile v' False) -> if v' == v then farthestPosition v (fromJust $ apply ps move) board move else ps
		Just _ -> ps
	position :: Board -> Position -> Position
	position board ps = farthestPosition (val $ getTile board ps) ps board move
	next :: Board -> Position -> Tile
	next board = (getTile board) . (position board)
	fromJust :: Maybe a -> a
	fromJust (Just x) = x

makeMove :: Board -> Move -> IO Board
makeMove board move = seed $ makeMoveNoSeed board move

data Player = Player { getMove :: Board -> IO Move }
humanPlayer :: Player
humanPlayer = Player { getMove = \board -> do {putStrLn (show board); putStr "move: "; line <- getLine; return (read line)} }


type Heuristic = Board -> Float
type Algorithm = Board -> Heuristic -> Int -> IO Move


minimax :: Board -> Int -> Bool -> Heuristic -> Float
minimax board depth _ h | depth == 0 || gameOver board = h board
minimax board depth True h = maximum . ([-1.0/0.0]++) $ map (\(x,_) -> minimax x (depth-1) False h) (moveList' board)
minimax board depth False h = sum $ map (\r@(RandomMove x _ _) -> (*x) $ minimax (applyRandomMove board r) (depth-1) True h) (seedOpts board) 

alphaBeta :: Board -> Int -> Bool -> Float -> Float -> Heuristic -> Float
alphaBeta board depth _ _ _ h | depth == 0 || gameOver board = h board
alphaBeta board depth True a b h = helper a  $ map (\(x,_) -> x) (moveList' board)
	where
	helper :: Float -> [Board] -> Float
	helper a' [] = a'
	helper a' (x:xs) = let y = alphaBeta x (depth-1) False a' b h in if b <= a' then a' else helper (max a' y) xs
alphaBeta board depth False a b h = helper b $ map (\(x,_) -> x) (moveList' board)
	where
	helper :: Float -> [Board] -> Float
	helper b' [] = b'
	helper b' (x:xs) = let y = alphaBeta x (depth-1) True a b' h in if b' <= a then a else helper (min b' y) xs

h1 :: Heuristic
h1 board = (fromIntegral $ score board) - (fromIntegral . length $ blanks board)

-- Source of significant slowdowns
h2 :: Heuristic
h2 board = (fromIntegral . score $ board) + (log . fromIntegral . length $ moveList board)

weightHeuristic :: [(Heuristic,Float)] -> Heuristic
weightHeuristic xs board = sum $ map (\(h,w) -> (*w) . h $ board) xs

monotonicity :: Heuristic
monotonicity board =  safeLog . sum $ map (helper . (map (val . (getTile board)))) rowsAndCols 
	where
	helper :: [Int] -> Float
	helper = fromIntegral . length . maximumBy (comparing length) . filter isSorted . subsequences
	isSorted :: [Int] -> Bool
	isSorted [] = True
	isSorted (0:_) = False	-- no zeros!
	isSorted [x] = True
	isSorted (x1:xs) = (x1 < head xs) && isSorted xs

monotonicity2 :: Heuristic
monotonicity2 board = sum $ map (helper (0.0,0.0) . (map (val . (getTile board)))) rowsAndCols
	where
	helper :: (Float,Float) -> [Int] -> Float
	helper (a,b) [] = max a b
	helper (a,b) [_] = max a b
	helper (a,b) (x1:x2:xs) = let cur = (safeLog . fromIntegral $ x1) in
		let nxt = (safeLog . fromIntegral $ x2) in
		if cur>nxt then helper (a+cur-nxt,b) (x2:xs) else helper (a,b+nxt-cur) (x2:xs)

h3 :: Heuristic
h3 = weightHeuristic [(monotonicity2,0.3),(h2,1.2)]

minimaxPlayer :: Int -> Heuristic -> Player
minimaxPlayer n h = Player { getMove = \board -> do {return $ argmax (\x -> minimax (makeMoveNoSeed board x) n True h) (moveList board) } }

alphaBetaPlayer :: Int -> Heuristic -> Player
alphaBetaPlayer n h = Player { getMove = \board -> do {return $ argmax (\x -> alphaBeta (makeMoveNoSeed board x) n True (-1.0/0.0) (1.0/0.0) h) (moveList board) } }


runGame :: Player -> IO ()
runGame player = seed newBoard >>= step player
	where
	step :: Player -> Board -> IO ()
	step player board | gameOver board = putStrLn $ show board
	step player board | otherwise = do
		move <- (getMove player) board
		board' <- makeMove board move
		putStrLn $ show move
		putStrLn $ show board'
		step player board'

main :: IO ()
main = runGame $ alphaBetaPlayer 12 h2

























