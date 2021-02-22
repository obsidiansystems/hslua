{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms            #-}
{-|
Module      : Foreign.Lua.Types
Copyright   : © 2007–2012 Gracjan Polak;
              © 2012–2016 Ömer Sinan Ağacan;
              © 2017-2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   : beta
Portability : non-portable (depends on GHC)

The core Lua types, including mappings of Lua types to Haskell.
-}
module Foreign.Lua.Types
  ( State (..)
  , Reader
  , TypeCode (..)
  , CFunction
  , LuaBool (..)
  , Integer (..)
  , Number (..)
  , StackIndex (..)
  , NumArgs (..)
  , NumResults (..)
  , OPCode (..)
  , StatusCode (..)
    -- * Garbage-Collection
  , GCCode (..)
  )
where

#include "lua.h"

import Prelude hiding (Integer)

import Data.Int (#{type LUA_INTEGER})
import Foreign.C (CChar, CInt, CSize)
import Foreign.Ptr (FunPtr, Ptr)
import Foreign.Storable (Storable)
import GHC.Generics (Generic)

-- | An opaque structure that points to a thread and indirectly (through the
-- thread) to the whole state of a Lua interpreter. The Lua library is fully
-- reentrant: it has no global variables. All information about a state is
-- accessible through this structure.
--
-- Synonym for @lua_State *@. See <https://www.lua.org/manual/5.3/#lua_State lua_State>.
newtype State = State (Ptr ()) deriving (Eq, Generic)

-- |  Type for C functions.
--
-- In order to communicate properly with Lua, a C function must use the
-- following protocol, which defines the way parameters and results are
-- passed: a C function receives its arguments from Lua in its stack in
-- direct order (the first argument is pushed first). So, when the
-- function starts, @'Foreign.Lua.Core.Functions.gettop'@ returns the
-- number of arguments received by the function. The first argument (if
-- any) is at index 1 and its last argument is at index
-- @'Foreign.Lua.Core.Functions.gettop'@. To return values to Lua, a C
-- function just pushes them onto the stack, in direct order (the first
-- result is pushed first), and returns the number of results. Any other
-- value in the stack below the results will be properly discarded by
-- Lua. Like a Lua function, a C function called by Lua can also return
-- many results.
--
-- See <https://www.lua.org/manual/5.3/manual.html#lua_CFunction lua_CFunction>.
type CFunction = FunPtr (State -> IO NumResults)

-- | The reader function used by @'Foreign.Lua.Core.Functions.load'@.
-- Every time it needs another piece of the chunk, lua_load calls the
-- reader, passing along its data parameter. The reader must return a
-- pointer to a block of memory with a new piece of the chunk and set
-- size to the block size. The block must exist until the reader
-- function is called again. To signal the end of the chunk, the reader
-- must return @NULL@ or set size to zero. The reader function may
-- return pieces of any size greater than zero.
--
-- See <https://www.lua.org/manual/5.3/manual.html#lua_Reader lua_Reader>.
type Reader = FunPtr (State -> Ptr () -> Ptr CSize -> IO (Ptr CChar))

-- |  The type of integers in Lua.
--
-- By default this type is @'Int64'@, but that can be changed to different
-- values in lua. (See @LUA_INT_TYPE@ in @luaconf.h@.)
--
-- See <https://www.lua.org/manual/5.3/manual.html#lua_Integer lua_Integer>.
newtype Integer = Integer #{type LUA_INTEGER}
  deriving (Bounded, Enum, Eq, Integral, Num, Ord, Real, Show)

-- |  The type of floats in Lua.
--
-- By default this type is @'Double'@, but that can be changed in Lua to a
-- single float or a long double. (See @LUA_FLOAT_TYPE@ in @luaconf.h@.)
--
-- See <https://www.lua.org/manual/5.3/manual.html#lua_Number lua_Number>.
newtype Number = Number #{type LUA_NUMBER}
  deriving (Eq, Floating, Fractional, Num, Ord, Real, RealFloat, RealFrac, Show)


--
-- LuaBool
--

-- | Boolean value returned by a Lua C API function. This is a @'CInt'@ and
-- interpreted as @'False'@ iff the value is @0@, @'True'@ otherwise.
newtype LuaBool = LuaBool CInt
  deriving (Eq, Storable, Show)

-- | Integer code used to encode the type of a Lua value.
newtype TypeCode = TypeCode { fromTypeCode :: CInt }
  deriving (Eq, Ord, Show)

-- | Relational operator code.
newtype OPCode = OPCode CInt deriving (Eq, Storable)

-- | Integer code used to signal the status of a thread or computation.
newtype StatusCode = StatusCode CInt deriving (Eq, Storable)

-- | Garbage-collection options.
newtype GCCode = GCCode CInt deriving (Eq, Storable)

-- | A stack index
newtype StackIndex = StackIndex { fromStackIndex :: CInt }
  deriving (Enum, Eq, Num, Ord, Show)

--
-- Number of arguments and return values
--

-- | The number of arguments consumed curing a function call.
newtype NumArgs = NumArgs { fromNumArgs :: CInt }
  deriving (Eq, Num, Ord, Show)

-- | The number of results returned by a function call.
newtype NumResults = NumResults { fromNumResults :: CInt }
  deriving (Eq, Num, Ord, Show)
