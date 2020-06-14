{-# LANGUAGE NamedFieldPuns #-}

module Crypto.Fido2.Assertion
  ( Error (..),
    verifyAssertionResponse,
  )
where

import qualified Crypto.Fido2.Protocol as Fido2
import qualified Crypto.Hash as Hash
import Crypto.Hash (Digest, SHA256)
import Data.Text (Text)
import qualified Data.Text.Encoding as Text

data Error
  = Error
  deriving (Show, Eq)

verifyAssertionResponse ::
  Fido2.Origin ->
  Fido2.RpId ->
  Fido2.Challenge ->
  Maybe [Fido2.PublicKeyCredentialDescriptor] ->
  Fido2.PublicKeyCredential Fido2.AuthenticatorAssertionResponse ->
  Either Error ()
verifyAssertionResponse
  origin
  ripId
  challenge
  allowCredentials
  Fido2.PublicKeyCredential {id, rawId, response, typ} = do
    -- When verifying a given PublicKeyCredential structure (credential) and an
    -- AuthenticationExtensionsClientOutputs structure clientExtensionResults, as
    -- part of an authentication ceremony, the Relying Party MUST proceed as
    -- follows:
    --
    -- 1. If the allowCredentials option was given when this authentication ceremony
    -- was initiated, verify that credential.id identifies one of the public key
    -- credentials that were listed in allowCredentials.
    --
    -- 2. Identify the user being authenticated and verify that this user is the owner
    -- of the public key credential source credentialSource identified by
    -- credential.id:
    --
    --   - If the user was identified before the authentication ceremony was initiated,
    --     verify that the identified user is the owner of credentialSource. If
    --     credential.response.userHandle is present, verify that this value identifies
    --     the same user as was previously identified.
    --
    --   - If the user was not identified before the authentication ceremony was
    --     initiated, verify that credential.response.userHandle is present, and that
    --     the user identified by this value is the owner of credentialSource.
    --
    -- 3. Using credential’s id attribute (or the corresponding rawId, if base64url
    -- encoding is inappropriate for your use case), look up the corresponding
    -- credential public key.
    --
    -- 4. Let cData, authData and sig denote the value of credential’s response's
    -- clientDataJSON, authenticatorData, and signature respectively.
    --
    -- 5. Let JSONtext be the result of running UTF-8 decode on the value of cData.
    --
    -- Note: Using any implementation of UTF-8 decode is acceptable as long as it
    -- yields the same result as that yielded by the UTF-8 decode algorithm. In
    -- particular, any leading byte order mark (BOM) MUST be stripped.
    --
    -- 6. Let C, the client data claimed as used for the signature, be the result of
    -- running an implementation-specific JSON parser on JSONtext.
    --
    -- Note: C may be any implementation-specific data structure representation, as
    -- long as C’s components are referenceable, as required by this algorithm.
    --
    -- 7. Verify that the value of C.type is the string webauthn.get.
    --
    -- 8. Verify that the value of C.challenge matches the challenge that was sent to
    -- the authenticator in the PublicKeyCredentialRequestOptions passed to the
    -- get() call.
    --
    -- 9. Verify that the value of C.origin matches the Relying Party's origin.
    --
    -- 10. Verify that the value of C.tokenBinding.status matches the state of Token
    -- Binding for the TLS connection over which the attestation was obtained. If
    -- Token Binding was used on that TLS connection, also verify that
    -- C.tokenBinding.id matches the base64url encoding of the Token Binding ID for
    -- the connection.
    --
    -- 11. Verify that the rpIdHash in authData is the SHA-256 hash of the RP ID
    -- expected by the Relying Party.
    --
    -- 12. Verify that the User Present bit of the flags in authData is set.
    --
    -- 13. If user verification is required for this assertion, verify that the User
    -- Verified bit of the flags in authData is set.
    --
    -- 14. Verify that the values of the client extension outputs in
    -- clientExtensionResults and the authenticator extension outputs in the
    -- extensions in authData are as expected, considering the client extension
    -- input values that were given as the extensions option in the get() call. In
    -- particular, any extension identifier values in the clientExtensionResults
    -- and the extensions in authData MUST be also be present as extension
    -- identifier values in the extensions member of options, i.e., no extensions
    -- are present that were not requested. In the general case, the meaning of
    -- "are as expected" is specific to the Relying Party and which extensions are
    -- in use.
    --
    -- Note: Since all extensions are OPTIONAL for both the client and the
    -- authenticator, the Relying Party MUST be prepared to handle cases where none
    -- or not all of the requested extensions were acted upon.
    --
    -- 15. Let hash be the result of computing a hash over the cData using SHA-256.
    --
    -- 16. Using the credential public key looked up in step 3, verify that sig is a
    -- valid signature over the binary concatenation of authData and hash.
    --
    -- Note: This verification step is compatible with signatures generated by FIDO
    -- U2F authenticators. See §6.1.2 FIDO U2F Signature Format Compatibility.
    --
    -- 17. If the signature counter value authData.signCount is nonzero or the value
    -- stored in conjunction with credential’s id attribute is nonzero, then run
    -- the following sub-step:
    --
    --  - If the signature counter value authData.signCount is
    --
    --    - greater than the signature counter value stored in conjunction with
    --      credential’s id attribute.  Update the stored signature counter value,
    --      associated with credential’s id attribute, to be the value of
    --      authData.signCount.
    --    - less than or equal to the signature counter value stored in conjunction
    --      with credential’s id attribute.  This is a signal that the authenticator
    --      may be cloned, i.e. at least two copies of the credential private key may
    --      exist and are being used in parallel. Relying Parties should incorporate
    --      this information into their risk scoring. Whether the Relying Party updates
    --      the stored signature counter value in this case, or not, or fails the
    --      authentication ceremony or not, is Relying Party-specific.
    --
    -- If all the above steps are successful, continue with the authentication
    -- ceremony as appropriate. Otherwise, fail the authentication ceremony.
    undefined
