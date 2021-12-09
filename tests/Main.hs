{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RecordWildCards #-}

module Main
  ( main,
  )
where

import Crypto.Hash (hash)
import qualified Crypto.WebAuthn.Model as M
import qualified Crypto.WebAuthn.Model.JavaScript as JS
import qualified Crypto.WebAuthn.Model.JavaScript.Decoding as JS
import qualified Crypto.WebAuthn.Operations.Assertion as WebAuthn
import Crypto.WebAuthn.Operations.Attestation (AttestationError)
import qualified Crypto.WebAuthn.Operations.Attestation as WebAuthn
import qualified Crypto.WebAuthn.Operations.Common as Common
import qualified Crypto.WebAuthn.PublicKey as PublicKey
import Data.Aeson (FromJSON)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Either (isRight)
import Data.Foldable (for_)
import Data.List.NonEmpty (NonEmpty)
import Data.Validation (toEither)
import qualified Emulation
import qualified Encoding
import GHC.Stack (HasCallStack)
import qualified MetadataSpec
import qualified PublicKeySpec
import Spec.Util (decodeFile)
import qualified System.Directory as Directory
import System.FilePath ((</>))
import Test.Hspec (Spec, describe, it, shouldSatisfy)
import qualified Test.Hspec as Hspec
import Test.QuickCheck.Instances.Text ()

-- Load all files in the given directory, and ensure that all of them can be
-- decoded. The caller can pass in a function to run further checks on the
-- decoded value, but this is mainly there to ensure that `a` occurs after the
-- fat arrow.
canDecodeAllToJSRepr :: (FromJSON a, HasCallStack) => FilePath -> (a -> IO ()) -> Spec
canDecodeAllToJSRepr path inspect = do
  files <- Hspec.runIO $ Directory.listDirectory path
  for_ files $ \fname ->
    it ("can decode " <> (path </> fname)) $ do
      bytes <- ByteString.readFile $ path </> fname
      case Aeson.eitherDecode' $ LazyByteString.fromStrict bytes of
        Left err -> fail err
        Right value -> inspect value

ignoreDecodedValue :: a -> IO ()
ignoreDecodedValue _ = pure ()

main :: IO ()
main = Hspec.hspec $ do
  describe "Decode test responses" $ do
    -- Check if all attestation responses can be decoded
    describe "attestation responses" $
      canDecodeAllToJSRepr
        @(JS.PublicKeyCredential JS.AuthenticatorAttestationResponse)
        "tests/responses/attestation/"
        ignoreDecodedValue
    -- Check if all assertion responses can be decoded
    describe "assertion responses" $
      canDecodeAllToJSRepr
        @(JS.PublicKeyCredential JS.AuthenticatorAssertionResponse)
        "tests/responses/assertion/"
        ignoreDecodedValue
  -- Test public key related tests
  describe "PublicKey" PublicKeySpec.spec
  describe
    "Metadata"
    MetadataSpec.spec
  describe
    "Emulation"
    Emulation.spec
  describe
    "Encoding"
    Encoding.spec
  describe "RegisterAndLogin" $
    it "tests whether the fixed register and login responses are matching" $
      do
        pkCredential <-
          either (error . show) id . JS.decodeCreatedPublicKeyCredential WebAuthn.allSupportedFormats
            <$> decodeFile
              "tests/responses/attestation/01-none.json"
        let options = defaultPublicKeyCredentialCreationOptions pkCredential
            registerResult =
              toEither $
                WebAuthn.verifyAttestationResponse
                  (M.Origin "http://localhost:8080")
                  (rpIdHash "localhost")
                  options
                  pkCredential
        registerResult `shouldSatisfy` isExpectedAttestationResponse pkCredential options
        let Right credentialEntry = registerResult
        loginReq <-
          either (error . show) id . JS.decodeRequestedPublicKeyCredential
            <$> decodeFile
              @(JS.PublicKeyCredential JS.AuthenticatorAssertionResponse)
              "tests/responses/assertion/01-none.json"
        let M.PublicKeyCredential {M.pkcResponse = pkcResponse} = loginReq
            signInResult =
              toEither $
                WebAuthn.verifyAssertionResponse
                  (M.Origin "http://localhost:8080")
                  (rpIdHash "localhost")
                  (Just (M.UserHandle "UserId"))
                  credentialEntry
                  (defaultPublicKeyCredentialRequestOptions loginReq)
                  M.PublicKeyCredential
                    { M.pkcIdentifier = Common.ceCredentialId credentialEntry,
                      M.pkcResponse = pkcResponse,
                      M.pkcClientExtensionResults = M.AuthenticationExtensionsClientOutputs {}
                    }
        signInResult `shouldSatisfy` isRight
  describe "Packed register" $
    it "tests whether the fixed packed register has a valid attestation" $
      do
        pkCredential <-
          either (error . show) id . JS.decodeCreatedPublicKeyCredential WebAuthn.allSupportedFormats
            <$> decodeFile
              "tests/responses/attestation/02-packed.json"
        let options = defaultPublicKeyCredentialCreationOptions pkCredential
            registerResult =
              toEither $
                WebAuthn.verifyAttestationResponse
                  (M.Origin "https://localhost:44329")
                  (rpIdHash "localhost")
                  options
                  pkCredential
        registerResult `shouldSatisfy` isExpectedAttestationResponse pkCredential options
  describe "AndroidKey register" $
    it "tests whether the fixed android key register has a valid attestation" $
      do
        pkCredential <-
          either (error . show) id . JS.decodeCreatedPublicKeyCredential WebAuthn.allSupportedFormats
            <$> decodeFile
              "tests/responses/attestation/03-android-key.json"
        let options = defaultPublicKeyCredentialCreationOptions pkCredential
            registerResult =
              toEither $
                WebAuthn.verifyAttestationResponse
                  (M.Origin "https://localhost:44329")
                  (rpIdHash "localhost")
                  options
                  pkCredential
        registerResult `shouldSatisfy` isExpectedAttestationResponse pkCredential options
  describe "U2F register" $
    it "tests whether the fixed fido-u2f register has a valid attestation" $
      do
        pkCredential <-
          either (error . show) id . JS.decodeCreatedPublicKeyCredential WebAuthn.allSupportedFormats
            <$> decodeFile
              "tests/responses/attestation/04-u2f.json"
        let options = defaultPublicKeyCredentialCreationOptions pkCredential
            registerResult =
              toEither $
                WebAuthn.verifyAttestationResponse
                  (M.Origin "https://localhost:44329")
                  (rpIdHash "localhost")
                  options
                  pkCredential
        registerResult `shouldSatisfy` isExpectedAttestationResponse pkCredential options
  describe "Apple register" $
    it "tests whether the fixed apple register has a valid attestation" $
      do
        pkCredential <-
          either (error . show) id . JS.decodeCreatedPublicKeyCredential WebAuthn.allSupportedFormats
            <$> decodeFile
              "tests/responses/attestation/05-apple.json"
        let options = defaultPublicKeyCredentialCreationOptions pkCredential
            registerResult =
              toEither $
                WebAuthn.verifyAttestationResponse
                  (M.Origin "https://6cc3c9e7967a.ngrok.io")
                  (rpIdHash "6cc3c9e7967a.ngrok.io")
                  options
                  pkCredential
        registerResult `shouldSatisfy` isExpectedAttestationResponse pkCredential options

isExpectedAttestationResponse :: M.PublicKeyCredential 'M.Create 'True -> M.PublicKeyCredentialOptions 'M.Create -> Either (NonEmpty AttestationError) Common.CredentialEntry -> Bool
isExpectedAttestationResponse _ _ (Left _) = False -- We should never receive errors
isExpectedAttestationResponse M.PublicKeyCredential {..} M.PublicKeyCredentialCreationOptions {..} (Right ce) =
  ce == expectedCredentialEntry
  where
    expectedCredentialEntry :: Common.CredentialEntry
    expectedCredentialEntry =
      Common.CredentialEntry
        { ceCredentialId = pkcIdentifier,
          ceUserHandle = M.pkcueId pkcocUser,
          cePublicKeyBytes =
            M.PublicKeyBytes . M.unRaw
              . M.acdCredentialPublicKeyBytes
              . M.adAttestedCredentialData
              . M.aoAuthData
              $ M.arcAttestationObject pkcResponse,
          ceSignCounter = M.adSignCount . M.aoAuthData $ M.arcAttestationObject pkcResponse
        }

defaultPublicKeyCredentialCreationOptions :: M.PublicKeyCredential 'M.Create raw -> M.PublicKeyCredentialOptions 'M.Create
defaultPublicKeyCredentialCreationOptions pkc =
  M.PublicKeyCredentialCreationOptions
    { M.pkcocRp =
        M.PublicKeyCredentialRpEntity
          { M.pkcreId = Just "localhost",
            M.pkcreName = "Tweag I/O Test Server"
          },
      M.pkcocUser =
        M.PublicKeyCredentialUserEntity
          { M.pkcueId = M.UserHandle "UserId",
            M.pkcueDisplayName = "UserDisplayName",
            M.pkcueName = "UserAccountName"
          },
      M.pkcocChallenge = M.ccdChallenge . M.arcClientData $ M.pkcResponse pkc,
      M.pkcocPubKeyCredParams =
        [ M.PublicKeyCredentialParameters
            { M.pkcpTyp = M.PublicKeyCredentialTypePublicKey,
              M.pkcpAlg = PublicKey.COSEAlgorithmIdentifierES256
            }
        ],
      M.pkcocTimeout = Nothing,
      M.pkcocExcludeCredentials = [],
      M.pkcocAuthenticatorSelection = Nothing,
      M.pkcocAttestation = M.AttestationConveyancePreferenceNone,
      M.pkcocExtensions = Nothing
    }

defaultPublicKeyCredentialRequestOptions :: M.PublicKeyCredential 'M.Get raw -> M.PublicKeyCredentialOptions 'M.Get
defaultPublicKeyCredentialRequestOptions pkc =
  M.PublicKeyCredentialRequestOptions
    { M.pkcogChallenge = M.ccdChallenge . M.argClientData $ M.pkcResponse pkc,
      M.pkcogTimeout = Nothing,
      M.pkcogRpId = Just "localhost",
      M.pkcogAllowCredentials = [],
      M.pkcogUserVerification = M.UserVerificationRequirementPreferred,
      M.pkcogExtensions = Nothing
    }

rpIdHash :: ByteString.ByteString -> M.RpIdHash
rpIdHash = M.RpIdHash . hash
