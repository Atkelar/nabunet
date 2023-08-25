using System;
using System.IdentityModel.Tokens.Jwt;
using System.IO;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;

namespace NabuNet
{
    public class ApiTokenSigner
    {
        private readonly SigningCredentials? _Signing;
        private readonly JsonWebKey? _Validating;

        public ApiTokenSigner(string keyFile)
        {
            if (File.Exists(keyFile))
            {
                string privateKey = File.ReadAllText(keyFile);
                _Signing = new SigningCredentials(
                            new Microsoft.IdentityModel.Tokens.JsonWebKey(privateKey),
                            SecurityAlgorithms.RsaSha256 // Signature
                        );
                _Validating = new Microsoft.IdentityModel.Tokens.JsonWebKey(privateKey);
                // remove private key parameters
                _Validating.P = null;
                _Validating.D = null;
                _Validating.DP = null;
                _Validating.DQ = null;
                _Validating.Q = null;
                _Validating.QI = null;
            }
        }

        public JsonWebKey? ValiationKey => _Validating;

        public string? CreateSignedToken(ClaimsIdentity identity, out DateTime? expires)
        {
            expires = null;
            if (_Signing == null)
                return null;

            JwtSecurityTokenHandler handler = new JwtSecurityTokenHandler();

            var now = DateTime.UtcNow;
            expires = now.AddSeconds(120);

            var descriptor = new SecurityTokenDescriptor()
            {
                Issuer = "NabuNet",
                Audience = "api",
                IssuedAt = now,
                NotBefore = now,
                Expires = expires,
                Subject = identity,
                SigningCredentials = _Signing
            };

            return handler.CreateEncodedJwt(descriptor);
        }
    }
}