{-# OPTIONS_GHC -Wall #-}

module Main where

import           Control.Monad       (mapM)
import qualified Data.List           as List
import qualified Data.Map            as Map
import qualified Data.Text.Lazy

import           Elm.Compiler
import           Elm.Compiler.Module
import           Elm.Package

import qualified Utils.File

-- import AST.Declaration import AST.Variable import AST.Module import AST.Module.Name import
-- AST.Type
{-

In order to run the compiler we need several pieces of data:

-- Elm.Package
data Name = Name { user :: String, project :: String }
data Version = Version { _major :: Int, _minor :: Int, _patch :: Int }
type Package = (Name, Version)

-- Elm.Compiler.Module
data Interface = Interface {
    iVersion  :: Package.Version,
    iPackage  :: Package.Name,
    iExports  :: [Var.Value],
    iImports  :: [AST.Module.Name.Raw],
    iTypes    :: Types,
    iUnions   :: Unions,
    iAliases  :: Aliases,
    iFixities :: [AST.Declaration.Infix]
}
type Interfaces = Map AST.Module.Name.Canonical Interface

-- AST.Declaration
data Assoc = L | N | R
data Infix = Infix { _op :: String, _associativity :: Assoc, _precedence :: Int }

-- AST.Variable
data Listing a = Listing
    { _explicits :: [a]
    , _open :: Bool
    }
data Value
    = Value !String
    | Alias !String
    | Union !String !(Listing String)

-- AST.Module
type Types = Map String Type.Canonical
type Unions = Map String (UnionInfo String)
type Aliases = Map String ([String], Type.Canonical)
type UnionInfo = ( [String], [(v, [Type.Canonical])] )

-- AST.Module.Name
type Raw = [String]
data Canonical = Canonical { _package :: Package.Name, _module :: Raw }

-- AST.Type
data Canonical
    = Lambda Canonical Canonical
    | Var String
    | Type Var.Canonical
    | App Canonical [Canonical]
    | Record [(String, Canonical)] (Maybe Canonical)
    | Aliased Var.Canonical [(String, Canonical)] (Aliased Canonical)

-- Elm.Compiler
data Context = Context {
    _packageName :: Package.Name,
    _isExposed :: bool,
    _dependencies :: [AST.Module.Name.Canonical]
}

compile :: Context -> String -> Elm.Package.Interfaces -> *stuff* :-)

-}
main :: IO ()
main =
  -- Grab the package version so we can lookup the built modules according to compiler version
  let (Version major minor patch) = Elm.Compiler.version
  in let versionString = List.intercalate "." (map show [major, minor, patch])
     in
     -- Some source code to compile for now
     let source = "module Test exposing (..)\n\nx = 3"
     in
     -- The repository that elm-lang lives in
     let elmCore = Name { user = "elm-lang", project = "core" }
     in
     -- Modules matched to the default imports
     let importModules = [ ["Basics"]
                         , ["Debug"]
                         , ["List"]
                         , ["Maybe"]
                         , ["Result"]
                         , ["Platform"]
                         , ["Platform", "Cmd"]
                         , ["Platform", "Sub"]
                         ]
     in
     -- Make a list of the names of modules we need to import
     let canonicalNames = map (\n -> Elm.Compiler.Module.Canonical elmCore n) importModules
     in
     -- A compiler context indicating that we need to import at least the default modules
     let context = Context
                     { _packageName = Name { user = "elm-lang", project = "test" }
                     , _isExposed = False
                     , _dependencies = canonicalNames
                     }
     in
     -- A function to make the hyphenated version of a package name as in build-artifacts
     let hyphenate rawName = List.intercalate "-" rawName
     in
     -- A function that builds the relative file name in elm-stuff of an elmi file. We cheat on
     -- the version number.
     let fileName (Elm.Compiler.Module.Canonical (Name user project) modPath) = List.intercalate "/"
              [ "elm-stuff"
              , "build-artifacts"
              , versionString
              , user
              , project
              , "4.0.0"
              , (hyphenate
                   modPath) ++ ".elmi"
              ]
     in
     -- A function to yield a pair of canonical name and binary interface from a canonical module
     -- name
     let readInterface name = do
         filename <- pure $ fileName name
         interface <- Utils.File.readBinary filename
         return (name, interface)
     in
     do
       -- Load up the interfaces into an IO [(Canonical, Interface)]
       interfaces <- mapM readInterface canonicalNames
       -- Make the interface map that the compiler consumes
       interfaceMap <- pure $ Map.fromList interfaces
       -- Attempt compilation
       (localizer, warnings, result) <- pure (Elm.Compiler.compile context source interfaceMap)
       case result of
         Left e ->
           -- Failure, print the errors
           putStrLn
             ((List.intercalate "\n" (map (Elm.Compiler.errorToString localizer "" source) e)) ++ "\n")
         Right (Result docs interface js) ->
           -- Success, print the javascript only for the requested module
           putStrLn (Data.Text.Lazy.unpack js)