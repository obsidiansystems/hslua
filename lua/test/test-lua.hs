{-# LANGUAGE CPP #-}
{-|
Module      : Main
Copyright   : © 2021 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   : beta

Tests for the raw Lua bindings.
-}
module Main (main) where

#ifdef ALLOW_UNSAFE_GC
import Control.Monad (void)
#else
import Control.Monad (forM_, void)
import Data.IORef (newIORef, readIORef, writeIORef)
#endif

import Foreign.C.String (peekCString, withCStringLen)
import Foreign.Marshal (alloca)
import Foreign.Ptr (nullPtr)
import Foreign.Storable as Storable
import Foreign.Lua
import Foreign.Lua.Call
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit
  ( Assertion, assertBool, testCase, (@=?) )

-- | Runs tests.
main :: IO ()
main = defaultMain tests

-- | Specifications for Attributes parsing functions.
tests :: TestTree
tests = testGroup "lua"
  [ testGroup "state"
    [ "create and close" =: do
      l <- hsluaL_newstate
      lua_close l

    , "newthread" =: do
        (a, b) <- withNewState $ \l -> do
          l1 <- lua_newthread l
          lua_pushnumber l 5
          lua_pushnumber l1 23
          (,) <$> lua_tonumberx l  top nullPtr
              <*> lua_tonumberx l1 top nullPtr
        5  @=? a
        23 @=? b
    ]

  , testGroup "booleans"
    [ "push and retrieve" =: do
        b <- withNewState $ \l -> do
          lua_pushboolean l true
          lua_toboolean l top
        true @=? b

    , "type" =: do
        ty <- withNewState $ \l -> do
          lua_pushboolean l false
          lua_type l top
        TypeBoolean @=? toType ty
    ]

  , testGroup "numbers"
    [ "push and retrieve" =: do
        i <- withNewState $ \l -> do
          lua_pushinteger l 5
          lua_tointegerx l top nullPtr
        5 @=? i

    , "type" =: do
        ty <- withNewState $ \l -> do
          lua_pushinteger l 0
          lua_type l top
        TypeNumber @=? toType ty
    ]

  , testGroup "strings"
    [ "push and retrieve" =: do
        str <- withNewState $ \l -> do
          withCStringLen "testing" $ \(ptr, len) ->
            lua_pushlstring l ptr (fromIntegral len)
          peekCString =<< lua_tolstring l top nullPtr
        "testing" @=? str

    , "type" =: do
        ty <- withNewState $ \l -> do
          withCStringLen "Olsen Olsen" $ \(ptr, len) ->
            lua_pushlstring l ptr (fromIntegral len)
          lua_type l top
        TypeString @=? toType ty
    ]

  , testGroup "constants"
    [ "loadedTableRegistryField"  =:
      ("_LOADED"  @=? loadedTableRegistryField)
    , "preloadTableRegistryField" =:
      ("_PRELOAD" @=? preloadTableRegistryField)
    ]

  , testGroup "compare"
    [ "equality" =: do
        b <- withNewState $ \l -> do
          lua_pushinteger l 42
          lua_pushnumber l 42
          hslua_compare l (nth 2) (nth 1) LUA_OPEQ nullPtr
        true @=? b

    , "less then" =: do
        b <- withNewState $ \l -> do
          lua_pushinteger l (-2)
          lua_pushnumber l 3
          hslua_compare l (nth 2) (nth 1) LUA_OPLT nullPtr
        true @=? b

    , "not less then" =: do
        b <- withNewState $ \l -> do
          lua_pushinteger l 42
          lua_pushnumber l 42
          hslua_compare l (nth 2) (nth 1) LUA_OPLT nullPtr
        false @=? b

    , "less then or equal" =: do
        b <- withNewState $ \l -> do
          lua_pushinteger l 23
          lua_pushnumber l 42
          alloca $ \statusPtr -> do
            result <- hslua_compare l (nth 2) (nth 1) LUA_OPLE statusPtr
            status <- Storable.peek statusPtr
            assertBool "comparison failed" (LUA_OK == status)
            return result
        true @=? b
    ]

  , testGroup "garbage-collection"
    [ "stop, restart GC"  =: do
        counts <- withNewState $ \l -> do
          lua_createtable l 0 0
          _  <- lua_gc l LUA_GCSTOP 0
          lua_pop l 1
          kb1 <- lua_gc l LUA_GCCOUNT 0
          b1  <- lua_gc l LUA_GCCOUNTB 0
          _   <- lua_gc l LUA_GCCOLLECT 0
          kb2 <- lua_gc l LUA_GCCOUNT 0
          b2  <- lua_gc l LUA_GCCOUNTB 0
          return (b1 + 1024 * kb1, b2 + 1024 * kb2)
        assertBool "first count should be larger" (fst counts > snd counts)
    , "count memory" =: do
        count <- withNewState $ \l -> do
          lua_gc l LUA_GCCOUNT 0
        assertBool "memory consumption not between 0 and 10 kB"
                   (count > 0 && count < 10)
    ]

  , testGroup "Haskell functions"
    [ let add5 l = do
            n <- lua_tointegerx l top nullPtr
            lua_pushinteger l $ n + 5
            return (NumResults 1)
      in "call Haskell function" =: do
        result <- withNewState $ \l -> do
          hslua_pushhsfunction l add5
          lua_pushinteger l 18
          void $ lua_pcall l (NumArgs 1) (NumResults 1) 0
          lua_tointegerx l (nth 1) nullPtr
        23 @=? result

#ifndef ALLOW_UNSAFE_GC
    , "Haskell function as finalizer" =: do
        msg <- newIORef "nope"
        let sendMessage _ = do
              writeIORef msg "HI MOM!"
              return (NumResults 0)
        result <- withNewState $ \l -> do
          -- create dummy table
          lua_createtable l 0 0
          -- create metatable with Haskell __gc function
          lua_createtable l 0 0
          withCStringLen "__gc" $ \(ptr, len) ->
            lua_pushlstring l ptr (fromIntegral len)
          hslua_pushhsfunction l sendMessage
          lua_rawset l (nth 3)
          -- set metatable with finalizer
          lua_setmetatable l (nth 2)
          -- remove dummy table from stack so the GC to collect it
          lua_pop l 1
          -- perform a large number of operations to allow the GC to kick in.
          forM_ [1..100] $ \i -> do
            -- push some string
            withCStringLen "some nonesense" $ \(ptr, len) ->
              lua_pushlstring l ptr (fromIntegral len)
            -- create new table with integer field
            lua_createtable l 0 0
            lua_pushinteger l i
            lua_pushinteger l 23
            lua_rawset l (nth 3)
            -- set empty table as metatable
            lua_createtable l 0 0
            lua_setmetatable l (nth 2)
            -- remove table and strings from stack
            lua_pop l 2
          -- the GC should have run now, check the message
          readIORef msg
        "HI MOM!" @=? result
#endif
    ]
  ]

infix  3 =:
(=:) :: String -> Assertion -> TestTree
(=:) = testCase
