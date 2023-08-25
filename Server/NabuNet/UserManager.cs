using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    public class UserManager
        : IUserManager
    {
        private readonly IDatabase _Database;
        private readonly IDataProtector _Protect;
        private readonly IDataProtector _ProtectTokens;
        private IDataProtector _ProtectApiTokens;
        private readonly IServerConfigFactory _ServerConfig;
        private readonly IMailSender _MailSender;
        private readonly ILogger<UserManager> _Logger;
        private readonly LoginSettings _LoginOptions;

        public UserManager(ILogger<UserManager> logger, IDatabase database, IDataProtectionProvider protectionProvider, IServerConfigFactory cfg, IMailSender mailsender, IOptions<LoginSettings> loginOptions)
        {
            _Database = database;
            _Protect = protectionProvider.CreateProtector("users");
            _ProtectTokens = protectionProvider.CreateProtector("xftokens");
            _ProtectApiTokens = protectionProvider.CreateProtector("apitoken");
            _ServerConfig = cfg;
            _MailSender = mailsender;
            _Logger = logger;
            _LoginOptions = loginOptions.Value;
        }

        private static string ExtractName(IKeyRecord user)
        {
            return ((UserProfile)user).Name;
        }

        private const string ProfileDocumentName = "profile";
        private const string CredentialsDocumentName = "cred";

        public Task<bool> Exists(string username)
        {
            return _Database.DocumentExists(ProfileDocumentName, username);
        }

        public async Task<UserProfile?> CreateUserFromSignup(string userName, string eMail, bool enable2FA, string password)
        {
            if (await _Database.DocumentExists(ProfileDocumentName, userName))
                return null;

            if (string.IsNullOrWhiteSpace(eMail))
                return null;

            var settings = await _ServerConfig.GetOrLoad();

            UserProfile p = new UserProfile()
            {
                ContactEMail = !settings.RequireMailValidation ? eMail : null,
                DisplayName = userName,
                Name = userName,
                HighscoreName = string.Empty,
                IsEnabled = settings.EnableNewUsers,
            };

            await _Database.SetDocumentAsync(ProfileDocumentName, p);

            UserCredentials cred = new UserCredentials();
            cred.Id = p.Id;

            cred.Enable2FA = enable2FA;
            var rng = System.Security.Cryptography.RandomNumberGenerator.Create();
            byte[] buffer = new byte[16];
            rng.GetNonZeroBytes(buffer);

            var sha = System.Security.Cryptography.SHA512.Create();

            cred.PWSalt = System.Convert.ToBase64String(buffer);
            cred.PWHash = System.Convert.ToBase64String(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(cred.PWSalt + password)));

            if (enable2FA)
            {
                byte[] seed = OtpNet.KeyGeneration.GenerateRandomKey(OtpNet.OtpHashMode.Sha512);
                cred.TimeBasedSeed = System.Convert.ToBase64String(_Protect.Protect(seed));
            }
            cred.Finished2FASetup = false;
            cred.Started2FASetup = DateTime.UtcNow;
            cred.ForcePasswordChange = false;
            cred.ProposedMailAddress = eMail;   // store proposed e-mail IN ANY CASE or it is lost...

            await _Database.SetDocumentAsync(CredentialsDocumentName, cred);

            if (p.ContactEMail == null && p.IsEnabled)
                await SendMailValidationMessage(p.Name, eMail);

            return p;
        }

        public async Task<bool> SendMailValidationMessage(string username, string newEMail)
        {
            var profile = await _Database.GetRequiredDocumentAsync<UserProfile>(ProfileDocumentName, username);
            if (profile == null)
                return false;

            await _Database.SetDocumentAsync<UserProfile>(ProfileDocumentName, profile);
            var cred = await _Database.GetRequiredDocumentAsync<UserCredentials>(CredentialsDocumentName, username);

            cred.MailValidationCode = Guid.NewGuid();
            cred.MailValidationExpiration = System.DateTime.UtcNow.AddMinutes(_LoginOptions.MailValidationTimeout);
            cred.ProposedMailAddress = newEMail;

            await _Database.SetDocumentAsync(CredentialsDocumentName, cred);

            var cfg = await _ServerConfig.GetOrLoad();

            if (profile.ContactEMail != null && profile.ContactEMail != newEMail)
            {
                if (!await _MailSender.TrySendMail(new MailingParameters()
                {
                    MailTemplateKey = "MailChangeRequested",
                    Recipients = new string[] { profile.ContactEMail },
                    Values = new System.Collections.Generic.Dictionary<string, string>()
                    {
                        {"reportpath", string.Format("Contact/Report?topic=emu&userhint={0}", username)},
                        {"newaddress", newEMail},
                        {"username", username}
                    }
                }))
                    _Logger.LogError("Couldn't send mail change notificatin to {mail} for new address {newMail}", profile.ContactEMail, newEMail);
            }

            if (!await _MailSender.TrySendMail(new MailingParameters()
            {
                MailTemplateKey = "ValidateMail",
                Recipients = new string[] { newEMail },
                Values = new System.Collections.Generic.Dictionary<string, string>()
                    {
                        {"path", string.Format("Profile/MailValidate?code={0}&token={1}", cred.MailValidationCode,
                            Uri.EscapeDataString(MakeXFToken(username)))},
                        {"user", profile.Name},
                        {"expires", cfg.GetFormattedTime(cred.MailValidationExpiration.Value, true)}
                    }
            }))
                _Logger.LogError("Couldn't send vailidation e-mail to {newMail}!", newEMail);
            return true;
        }

        private async Task<bool> Send2FAUpdatedMail(string username)
        {
            var profile = await _Database.GetRequiredDocumentAsync<UserProfile>(ProfileDocumentName, username);
            if (profile == null || string.IsNullOrWhiteSpace(profile.ContactEMail))
                return false;
            if (profile.ContactEMail == null)
                return false;

            var cfg = await _ServerConfig.GetOrLoad();

            if (!await _MailSender.TrySendMail(new MailingParameters()
            {
                MailTemplateKey = "2FAUpdated",
                Recipients = new string[] { profile.ContactEMail },
                Values = new System.Collections.Generic.Dictionary<string, string>()
                    {
                        {"reportpath", string.Format("Contact/Report?topic=2fa&userhint={0}", username)},
                        {"username", profile.Name  }
                    }
            }))
                _Logger.LogError("Couldn't send 2FA Update e-mail!");
            return true;
        }

        public async Task<UserProfile?> GetProfileByName(string username)
        {
            return await _Database.GetDocumentAsync<UserProfile>(ProfileDocumentName, username);
        }

        public async Task<bool> ValidateUser2FA(string username, string response)
        {
            var cred = await _Database.GetDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            if (cred == null || !cred.Enable2FA)
                return false;

            var checker = new OtpNet.Totp(
                _Protect.Unprotect(Convert.FromBase64String(cred.TimeBasedSeed)),
                _LoginOptions.Period2FACode,
                OtpNet.OtpHashMode.Sha512,
                _LoginOptions.Digits2FACode);
            long matched;
            if (checker.VerifyTotp(response, out matched))
            {
                if (matched > cred.LastUsed2FATime.GetValueOrDefault())
                {
                    cred.LastUsed2FATime = matched;
                    cred.LastValid2FAConfirm = System.DateTime.UtcNow;
                    await _Database.SetDocumentAsync<UserCredentials>(CredentialsDocumentName, cred);
                    return true;
                }
            }
            return false;
        }


        public async Task<UserLoginStep1Result> ValidateUserPassword(string username, string password)
        {
            var cred = await _Database.GetDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            if (cred == null)
                return UserLoginStep1Result.Failed;

            var sha = System.Security.Cryptography.SHA512.Create();

            var check = System.Convert.ToBase64String(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(cred.PWSalt + password)));
            if (check == cred.PWHash)
            {
                // it **could** work...
                cred.LastValidPasswordLogin = DateTime.UtcNow;
                await _Database.SetDocumentAsync(CredentialsDocumentName, cred);
                var profile = await _Database.GetRequiredDocumentAsync<UserProfile>(ProfileDocumentName, username);
                if (profile.IsEnabled)
                {
                    if (cred.ForcePasswordChange)
                        return UserLoginStep1Result.ForceNewPassword;
                    if (cred.Enable2FA)
                    {
                        if (cred.Finished2FASetup)
                            return UserLoginStep1Result.GetFactorTwo;
                        return UserLoginStep1Result.SetupFactorTwo;
                    }
                    return UserLoginStep1Result.Success;
                }
            }
            return UserLoginStep1Result.Failed;
        }

        public async Task<Setup2FAParameters?> GetNew2FAChallenge(string username)
        {
            var cred = await _Database.GetDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            if (cred == null)
                return null;
            var cfg = await _ServerConfig.GetOrLoad();

            if (!await Send2FAUpdatedMail(username))    // if we continue below, we are devulging the 2FA code to *somebody*. Notify the user HERE instead of when the update actually happens!
                return null;

            string url = new OtpNet.OtpUri(
                    OtpNet.OtpType.Totp,
                    OtpNet.Base32Encoding.ToString(_Protect.Unprotect(Convert.FromBase64String(cred.TimeBasedSeed))),
                    username,
                    cfg.ServerName,
                    OtpNet.OtpHashMode.Sha512,
                    _LoginOptions.Digits2FACode,
                    _LoginOptions.Period2FACode
                    ).ToString();
            var code = new QRCodeCore.SvgQRCode(new QRCodeCore.QRCodeData(url));
            Setup2FAParameters parameters = new Setup2FAParameters()
            {
                QRCode = code.Create(256),
                OTPUrl = url,
                UserName = username
            };
            return parameters;
        }

        public async Task<string?> ExtractUserFromTokenForMailValidationAndCheck(string token, string code)
        {
            var username = await ExtractUserFromXFTokenAndValidate(token, TimeSpan.FromMinutes(_LoginOptions.MailValidationTimeout));
            if (username == null)
                return null;

            var cred = await _Database.GetDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            if (cred == null)
                return null;

            return cred.MailValidationExpiration.HasValue &&
                cred.MailValidationExpiration.Value >= DateTime.UtcNow &&
                cred.MailValidationCode.HasValue &&
                cred.MailValidationCode.Value == Guid.Parse(code) ? username : null;
        }

        private string MakeXFToken(string userName)
        {
            long now = System.DateTime.UtcNow.Ticks;
            string tokenContent = string.Format("{0:x16}-{1}", now, userName);
            return _Protect.Protect(tokenContent);
        }

        private async Task<string?> ExtractUserFromXFTokenAndValidate(string loginToken, TimeSpan timeout)
        {
            string token = _Protect.Unprotect(loginToken);
            if (token.Length > 17 && token[16] == '-')
            {
                string username = token.Substring(17);
                long then = long.Parse(token.Substring(0, 16), System.Globalization.NumberStyles.HexNumber);
                TimeSpan delta = TimeSpan.FromTicks(System.DateTime.UtcNow.Ticks - then);
                if (await Exists(username) && delta.TotalSeconds > 0 && delta <= timeout)
                {
                    return username;
                }
                else
                    _Logger.LogWarning("XF Token failed: Token content invalid or expired!");
            }
            else
                _Logger.LogWarning("XF Token failed: Token content invalid!");
            return null;
        }

        private async Task<bool> ValidateXFToken(string userName, string loginToken, TimeSpan timeout)
        {
            try
            {
                return userName.Equals(await ExtractUserFromXFTokenAndValidate(loginToken, timeout), StringComparison.InvariantCultureIgnoreCase);
            }
            catch (Exception ex)
            {
                _Logger.LogError(ex, "XF Token failed: Token Validation error!");
            }
            return false;
        }


        public Task<string> GetPageForwardToken(string username)
        {
            return Task.FromResult(MakeXFToken(username));
        }

        public Task<bool> ValidatePageForwardToken(string username, string token)
        {
            return ValidateXFToken(username, token, TimeSpan.FromSeconds(_LoginOptions.PageForwardingTimeout));
        }

        public async Task<UserLoginStep1Result> SetPassword(string userName, string newPassword, bool focePasswordChange = false)
        {
            var cred = await _Database.GetDocumentAsync<UserCredentials>(CredentialsDocumentName, userName);

            var sha = System.Security.Cryptography.SHA512.Create();
            cred.PWHash = System.Convert.ToBase64String(sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(cred.PWSalt + newPassword)));
            cred.ForcePasswordChange = focePasswordChange;

            await _Database.SetDocumentAsync(CredentialsDocumentName, cred);

            if (cred.Enable2FA)
            {
                if (cred.Finished2FASetup)
                    return UserLoginStep1Result.Success;
                return UserLoginStep1Result.SetupFactorTwo;
            }

            return UserLoginStep1Result.Success;
        }

        public async Task SetMailValidated(string username, string code)
        {
            var profile = await _Database.GetDocumentAsync<UserProfile>(ProfileDocumentName, username);
            if (profile == null)
                return;
            var cred = await _Database.GetRequiredDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            if (cred == null)
                return;
            if (cred.MailValidationCode.HasValue && cred.MailValidationCode == Guid.Parse(code) && cred.ProposedMailAddress != null && cred.MailValidationExpiration.Value <= DateTime.UtcNow.AddSeconds(1))
            {
                profile.ContactEMail = cred.ProposedMailAddress;
                cred.ProposedMailAddress = null;
                cred.MailValidationCode = null;
                cred.MailValidationExpiration = null;
            }
            await _Database.SetDocumentAsync(ProfileDocumentName, profile);
            await _Database.SetDocumentAsync(CredentialsDocumentName, cred);
        }
        public async Task Confirm2FASetup(string username)
        {
            var cred = await _Database.GetRequiredDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            cred.Finished2FASetup = true;
            await _Database.SetDocumentAsync(CredentialsDocumentName, cred);
        }

        public async Task UpdateProfileByName(string username, string displayName, string highScoreName, bool allowAPIAccess, bool allowDeviceAccess)
        {
            var profile = await _Database.GetDocumentAsync<UserProfile>(ProfileDocumentName, username);
            if (profile == null)
                return;
            profile.DisplayName = displayName;
            profile.HighscoreName = highScoreName;
            profile.EnableAPIAccess = allowAPIAccess;
            profile.EnableDeviceConnections = allowDeviceAccess;
            await _Database.SetDocumentAsync(ProfileDocumentName, profile);
        }

        public async Task StartEMailUpdate(string username, string eMailAddress)
        {
            var profile = await _Database.GetDocumentAsync<UserProfile>(ProfileDocumentName, username);
            if (profile == null || !profile.IsEnabled)
                return;
            var cfg = await _ServerConfig.GetOrLoad();
            if (cfg.RequireMailValidation)
            {
                await SendMailValidationMessage(username, eMailAddress);
            }
            else
            {
                if (profile.ContactEMail != null && profile.ContactEMail != eMailAddress)
                {
                    if (!await _MailSender.TrySendMail(new MailingParameters()
                    {
                        MailTemplateKey = "MailChangeRequested",
                        Recipients = new string[] { profile.ContactEMail },
                        Values = new System.Collections.Generic.Dictionary<string, string>()
                    {
                        {"reportpath", string.Format("Contact/Report?topic=emu&userhint={0}", username)},
                        {"newaddress", eMailAddress},
                        {"username", username}
                    }
                    }))
                        _Logger.LogError("Couldn't send mail change notificatin to {mail} for new address {newMail}", profile.ContactEMail, eMailAddress);
                }
                profile.ContactEMail = eMailAddress;
                await _Database.SetDocumentAsync(ProfileDocumentName, profile);
            }
        }

        public async Task<bool> IsMFAEnabled(string username)
        {
            var cred = await _Database.GetRequiredDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
            return cred.Enable2FA && cred.Finished2FASetup;
        }

        public async Task<bool> ApproveUser(string username)
        {
            var user = await _Database.GetRequiredDocumentAsync<UserProfile>(ProfileDocumentName, username);
            if (!user.IsEnabled)
            {
                user.IsEnabled = true;
                await _Database.SetDocumentAsync(ProfileDocumentName, user);
                var cred = await _Database.GetRequiredDocumentAsync<UserCredentials>(CredentialsDocumentName, username);
                // enable user...
                if (cred.ProposedMailAddress != null)
                {
                    return await SendMailValidationMessage(username, cred.ProposedMailAddress);
                }
            }
            return user.IsEnabled;
        }

        public async Task<IEnumerable<string>> GetUserNames()
        {
            return (await _Database.GetDocumentListAsync(ProfileDocumentName)).OrderBy(x => x);
        }

        private class UserTokenSerializer
            : IKeyRecord
        {
            public string? Id { get; set; }
            public string DeriveNewKey()
            {
                throw new NotImplementedException("shouldn't happen, shoul db be set by the code!");
            }

            public List<TokenInfo> Tokens { get; set; } = new List<TokenInfo>();
        }

        private const string TokenDocumentName = "tokens";


        public async Task DeleteUserToken(string username, Guid id)
        {
            var doc = await _Database.GetDocumentAsync<UserTokenSerializer>(TokenDocumentName, username);
            if (doc != null)
            {
                var item = doc.Tokens.Where(x => x.Id == id).FirstOrDefault();
                if (item != null)
                {
                    doc.Tokens.Remove(item);
                    await _Database.SetDocumentAsync(TokenDocumentName, doc);
                }
            }
        }
        public async Task<IEnumerable<TokenInfo>> GetTokensForUser(string name)
        {
            var doc = await _Database.GetDocumentAsync<UserTokenSerializer>(TokenDocumentName, name);
            if (doc == null)
                return Array.Empty<TokenInfo>();
            return doc.Tokens;
        }

        public async Task<(string username, TokenInfo token)?> GetValidatedToken(string tokenInput)
        {
            string tokenSecret = _ProtectApiTokens.Unprotect(tokenInput);
            // we should have: user:token:secret...
            int idx = tokenSecret.IndexOf(':');
            if (idx > 0 && idx <= 32)
            {
                string username = tokenSecret.Substring(0, idx);
                int idx2 = tokenSecret.IndexOf(':', idx + 1);
                if (idx2 - (idx + 1) == 32)
                {
                    Guid g = Guid.Parse(tokenSecret.Substring(idx + 1, 32));
                    byte[] buffer = new byte[48];
                    Buffer.BlockCopy(g.ToByteArray(), 0, buffer, 0, 16);
                    Buffer.BlockCopy(Convert.FromBase64String(tokenSecret.Substring(idx2 + 1)), 0, buffer, 16, 32);
                    SHA512 hash = SHA512.Create();
                    var hashed = Convert.ToBase64String(hash.ComputeHash(buffer));

                    var tokens = await _Database.GetDocumentAsync<UserTokenSerializer>(TokenDocumentName, username);
                    if (tokens != null)
                    {
                        var token = tokens.Tokens.FirstOrDefault(x => x.Id == g && (!x.ExpiresAt.HasValue || x.ExpiresAt.Value < DateTime.UtcNow) && x.Hash == hashed);
                        if (token != null)
                            return (username, token);
                    }
                }
            }
            return null;
        }

        public async Task<CreatedTokenInfo?> CreateToken(string username, string? name, bool enableSiteAdmin, bool enableUserAdmin, bool enableModerator, bool enableContentManager, DateTime? expires = null)
        {
            var profile = await GetProfileByName(username);
            if (profile == null)
                return null;
            if (!profile.IsEnabled || profile.ContactEMail == null)
                return null;
            // filter out any permissions that the user doesn't currently have, just for optics....
            enableSiteAdmin = profile.IsAdministrator && enableSiteAdmin;
            enableModerator = (profile.IsModerator || profile.IsAdministrator) && enableModerator;
            enableUserAdmin = (profile.IsUserAdministrator || profile.IsAdministrator) && enableUserAdmin;
            enableContentManager = (profile.IsContentManager || profile.IsAdministrator) && enableContentManager;

            SHA512 hash = SHA512.Create();
            byte[] secret = RandomNumberGenerator.GetBytes(48);
            var tokenId = Guid.NewGuid();
            Buffer.BlockCopy(tokenId.ToByteArray(), 0, secret, 0, 16);

            var hashed = Convert.ToBase64String(hash.ComputeHash(secret));
            var now = DateTime.UtcNow;

            var newToken = new TokenInfo()
            {
                ExpiresAt = expires,
                Id = tokenId,
                IsContentManager = enableContentManager,
                IsModerator = enableModerator,
                IsSiteAdmin = enableSiteAdmin,
                IsUserAdmin = enableUserAdmin,
                IssuedAt = now,
                Hash = hashed,
                Name = string.IsNullOrWhiteSpace(name) ? $"{now:yyyyMMdd-HH:mm:ss}-{tokenId.ToByteArray()[0]:x2}" : name
            };
            var doc = await _Database.GetDocumentAsync<UserTokenSerializer>(TokenDocumentName, username);
            if (doc == null)
                doc = new UserTokenSerializer() { Id = username };
            doc.Tokens.Add(newToken);
            await _Database.SetDocumentAsync(TokenDocumentName, doc);

            System.Text.StringBuilder sb = new System.Text.StringBuilder();
            sb.Append(username);
            sb.Append(':');
            sb.Append(tokenId.ToString("n"));
            sb.Append(':');
            sb.Append(Convert.ToBase64String(secret, 16, 32));

            return new CreatedTokenInfo(newToken) { TokenSecretValue = _ProtectApiTokens.Protect(sb.ToString()) };
        }

        public async Task<ClaimsPrincipal?> CreatePrincipal(string username, bool was2fa, TokenInfo? fromToken)
        {
            var claims = new List<Claim>();

            var profile = await GetProfileByName(username);
            if (profile == null || !(profile?.IsEnabled).GetValueOrDefault() || profile?.ContactEMail == null)
                return null;
            if (fromToken != null && !profile.EnableAPIAccess)
                return null;
            claims.Add(new Claim(SecurityTypes.UserTypeClaim, profile.IsFullUser() ? "user" : "guest"));
            if (fromToken != null)
                claims.Add(new Claim(SecurityTypes.LoginTypeClaim, SecurityTypes.LoginTypeApi));    // keep that in mind...

            claims.Add(new Claim(ClaimTypes.Name, profile.Name));
            if (was2fa)  // https://datatracker.ietf.org/doc/html/rfc8176#section-2
                claims.Add(new Claim("amr", "otp"));    // proud to be...

            // admins have all roles implied here...
            if (profile.IsAdministrator && (fromToken == null || fromToken.IsSiteAdmin))
                claims.Add(new Claim(ClaimTypes.Role, SecurityTypes.RoleAdministrator));
            if ((profile.IsAdministrator || profile.IsContentManager) && (fromToken == null || fromToken.IsContentManager))
                claims.Add(new Claim(ClaimTypes.Role, SecurityTypes.RoleContentManager));
            if ((profile.IsAdministrator || profile.IsModerator) && (fromToken == null || fromToken.IsModerator))
                claims.Add(new Claim(ClaimTypes.Role, SecurityTypes.RoleModerator));
            if ((profile.IsAdministrator || profile.IsUserAdministrator) && (fromToken == null || fromToken.IsUserAdmin))
                claims.Add(new Claim(ClaimTypes.Role, SecurityTypes.RoleUserAdmin));

            var identity = new ClaimsIdentity(claims, "nabunet");
            return new ClaimsPrincipal(identity);
        }
    }
}