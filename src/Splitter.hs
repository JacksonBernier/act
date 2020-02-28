{-# LANGUAGE DeriveGeneric  #-}
{-# Language DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleInstances  #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# Language TypeOperators #-}
import Data.List
import Data.Aeson hiding (Bool)
import Data.Aeson.Types hiding (Bool)
import GHC.Generics
import System.Environment ( getArgs )
import System.Exit ( exitFailure )
import Data.Text          (Text, pack, unpack)
import Data.Vector (fromList)
import qualified Data.ByteString.Lazy.Char8 as B

import AbsAct
import LexAct
import ParAct
import ErrM
import Options.Generic
--command line options
data Command w
  = Parse { file  :: w ::: String <?> "Path to file to parse"}
  | Compile { file :: w ::: String <?> "Path to file to parse"
            , k    :: w ::: Bool <?> "output k files"
            , ir   :: w ::: Bool <?> "output intermediate representation"
            , coq  :: w ::: Bool <?> "output coq files"
            , out  :: w ::: Maybe String <?> "output path"
            }
    deriving (Generic)

instance ParseRecord (Command Wrapped)
deriving instance Show (Command Unwrapped)

main :: IO ()
main = do
    cmd <- unwrapRecord "Act -- Smart contract specifier"
    case cmd of
      (Parse f) -> do contents <- readFile f      
                      case pAct $ myLexer contents of
                        (Ok (Main a)) -> do print "success"
                                            print a
                        (Bad s) -> error s

      (Type f) -> do contents <- readFile f      
                     case pAct $ myLexer contents of --todo: proper monadic lifts
                       (Ok (Main a)) -> case typecheck a of
                          (Ok a)  -> print "success"
                          (Bad s) -> error s
                       (Bad s) -> error s
      (Compile f _ _ _ out) -> case (ir cmd) of
        True -> do contents <- readFile f
                   case pAct $ myLexer contents of
                     (Ok (Main behaviours)) -> mapM_ (B.putStrLn . encode . split) behaviours
                     (Bad errormsg)         -> error errormsg
        False -> error "TODO"

typecheck :: [RawBehaviour] -> Err [Behaviour]
typecheck behvs = let store = lookupVars all in
                  map (\b -> (chk b store)) behvs

type Contract = Var

--checks a transition given a typing of its storage variables
lookupVars :: [Behaviour] -> Map Contract (Map Var Type)
lookupVars bs = _

chk :: RawBehaviour -> Map Contract (Map Var Type) -> Err Behaviour
chk b store = _


data TypedExp
  = Boolean BExp
  | Integer IExp
  | Bytes  ByExp

data BExp
    = BAnd  BExp BExp
    | BOr   BExp BExp
    | BImpl BExp BExp
    | BIEq  IExp IExp
    | BYEq  ByExp ByExp
    | BNeg  BExp
    | BLE   IExp IExp
    | BGE   IExp IExp

data IExp
    = Add Exp Exp
    | Sub Exp Exp
    | ITE BExp Exp Exp
    | Mul Exp Exp
    | Div Exp Exp
    | Mod Exp Exp
    | Exp Exp Exp


data StorageVar
    = Direct Var
    | Struct StorageVar Var
    | Lookup StorageVar 

-- AST post typechecking
data Behaviour = Behaviour
  {_name :: String,
   _contract :: Var,
   _interface :: (String, [Decl]),
   _preconditions :: [BExp],
   _cases :: Map BExp Update
  }

data Update = Update (Map Var [StorageUpdate]) MaybeReturn

  --                     pre       , post
data StorageUpdate = StorageUpdate StorageVar TypedExp
   
  

-- --Intermediate format
-- data Obligation = Obligation
--   { _name      :: String,
--     _contract  :: String,
--     _StatusCode :: String,
--     _methodName :: String,
--     _inputArgs  :: [Decl],
--     _return     :: (Exp, Type),
--     _preConditions :: [Exp]
-- --    _env        :: [(String, Var)],
-- -- --    _variables :: [(Var, Type)],
-- --     _preStore  :: [(Entry, Exp)],
-- --     _postStore :: [(Entry, Exp)],-
-- --     _postCondition :: [BExp]
--   } deriving (Show)

-- instance ToJSON Obligation where
--   toJSON (Obligation { .. }) =
--     object [ "name" .= _name
--            , "contract"  .= _contract
--            , "statusCode"  .= _StatusCode
--            , "methodName"  .= _methodName
--            , "inputArgs"   .= (Data.Aeson.Types.Array $ fromList (map
--                                                 (\(Dec abiType name) ->
--                                                   object [ "name" .= pprint name, "type" .= pprint abiType ])
--                                                  _inputArgs))
--            , "return"  .= object [ "value" .= pprint (fst _return), "type" .= pprint (snd _return) ]
--            , "preConditions"  .= (Data.Aeson.Types.Array $ fromList (fmap (String . pack . pprint) _preConditions))
--            -- , "calldata"  .= show _calldata
--            -- , "preStore"  .= show _preStore
--            -- , "postStore"  .= show _postStore
--            -- , "postCondition"  .= show _postCondition
--            ]


-- split :: Behaviour -> [Obligation]
-- split (Transition (Var name) (Var contract) (Var methodName) args iffs claim) =
--   case claim of
--     Direct (ReturnP returnExpr)  ->
--       --success case:
--       [Obligation
--       {_name     = name,
--        _contract = contract,
--        _StatusCode = "EVMC_SUCCESS",
--        _methodName = methodName,
--        _inputArgs  = args,
--        _return     = (returnExpr, getExpType returnExpr),
--        _preConditions  = concat $ fmap iffHToBool iffs
-- --       _env        = defaultEnv,
-- --       _calldata   = methodName args,
--        -- _variables  = [], --hmmm
--        -- _preStore   = [],
--        -- _postStore  = [],
--        -- _postCondition = []
--       }]
--     CaseSplit _ -> error "TODO"

-- getExpType :: Exp -> Type
-- getExpType (Int _) = Type_uint
-- getExpType (Bool _) = Type_bool
-- getExpType (Bytes _) = Type_bytes


-- defaultEnv :: [(String, Var)]
-- defaultEnv = [("CALLER", Var "CALLER_VAR")]
class Pretty a where
  pprint :: a -> String

instance Pretty Var where
  pprint (Var a) = a

instance Pretty Arg where
  pprint (Argm a) = pprint a


instance Pretty Exp where
-- integers
  pprint (EAdd x y) = pprint x <> " + " <> pprint y
  pprint (ESub x y) = pprint x <> " - " <> pprint y
  pprint (EMul x y) = pprint x <> " * " <> pprint y
  pprint (EDiv x y) = pprint x <> " / " <> pprint y
  pprint (EMod x y) = pprint x <> " % " <> pprint y
  pprint (EExp x y) = pprint x <> " ^ " <> pprint y
  pprint (EITE b x y) = "if" <> pprint b <>
                     "then" <> pprint x <>
                     "else" <> pprint y
  pprint Wild = "_"
  pprint (Func x y) = pprint x <> "(" <> intercalate "," (fmap pprint y) <> ")"
-- booleans
  pprint (EAnd x y)  = pprint x <> " and " <> pprint y
  pprint (EOr x y)   = pprint x <> " or "  <> pprint y
  pprint (EImpl x y) = pprint x <> " => "  <> pprint y
  pprint (EEq x y)   = pprint x <> " == "  <> pprint y
  pprint (ENeq x y)  = pprint x <> " =/= " <> pprint y
  pprint (ELEQ x y)  = pprint x <> " <= "  <> pprint y
  pprint (ELE x y)   = pprint x <> " < "   <> pprint y
  pprint (EGEQ x y)  = pprint x <> " >= "  <> pprint y
  pprint (EGE x y)   = pprint x <> " > "   <> pprint y
  pprint ETrue = "true"
  pprint EFalse = "false"
-- bytes
  pprint (Cat x y)  = pprint x <> "++" <> pprint y
  pprint (Slice byexp a b) = pprint byexp
    <> "[" <> show a <> ".." <> show b <> "]"
  pprint (Newaddr x) = "newAddr"  <> map pprint x
  pprint (Newaddr2 x) = "newAddr" <> map pprint x
  pprint (BYHash x) = "keccak256" <> pprint x
  pprint (BYAbiE x) = "abiEncode" <> pprint x


instance Pretty Type where
  pprint Type_uint = "uint256"
  pprint Type_int = "int256"
  pprint Type_bytes = "bytes"
  pprint Type_uint256 = "uint256"
  pprint Type_int256 = "int256"
  pprint Type_int126 = "int126"
  pprint Type_uint126 = "uint126"
  pprint Type_int8 = "int8"
  pprint Type_uint8 = "uint8"
  pprint Type_address = "address"
  pprint Type_bytes32 = "bytes32"
  pprint Type_bytes4 = "bytes4"
  pprint Type_bool = "bool"
  pprint Type_string = "string"

min :: Type -> Exp
min Type_uint = IntLit 0
min Type_uint256 = IntLit 0
min Type_uint126 = IntLit 0
min Type_uint8 = IntLit 0
--todo, the rest

max :: Type -> Exp
max Type_uint    = EInt 115792089237316195423570985008687907853269984665640564039
max Type_uint256 = EInt 115792089237316195423570985008687907853269984665640564039
max _ = error "todo: max"


--Prints an act expression as a K ByteArray
kPrintBytes :: Exp -> String
kPrintBytes _ = "TODO: krpintBytes" --todo

iffHToBool :: IffH -> [Exp]
iffHToBool (Iff bexps) = bexps
iffHToBool (IffIn abitype exprs) =
  fmap
    (\exp -> BAnd (BLEQ (Main.min abitype) exp) (BLEQ exp (Main.max abitype)))
    exprs